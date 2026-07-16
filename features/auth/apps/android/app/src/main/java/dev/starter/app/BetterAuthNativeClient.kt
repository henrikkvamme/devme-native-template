package dev.starter.app

import android.content.Context
import dev.convex.android.AuthProvider
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

enum class NativeSocialProvider(val wireName: String) {
  Apple("apple"),
  Google("google"),
}

data class NativeIdentityCredential(
  val provider: NativeSocialProvider,
  val idToken: String,
  val nonce: String? = null,
)

@JvmInline
value class BetterAuthBearerToken(val value: String)

@JvmInline
value class ConvexJwt(val value: String)

data class BetterAuthSession(
  val bearerToken: BetterAuthBearerToken,
  val convexToken: ConvexJwt,
)

interface NativeIdentityProvider {
  suspend fun signIn(context: Context): NativeIdentityCredential

  suspend fun signOut(context: Context)
}

interface BetterAuthBearerTokenStore {
  suspend fun load(): BetterAuthBearerToken?

  suspend fun save(token: BetterAuthBearerToken)

  suspend fun clear()
}

class BetterAuthRequestException(
  val status: Int,
  message: String,
) : Exception("Authentication failed with status $status: $message")

class BetterAuthNativeClient(
  siteUrl: String,
) {
  private val siteUrl = siteUrl.trimEnd('/')

  suspend fun signIn(credential: NativeIdentityCredential): BetterAuthSession {
    val idToken = JSONObject().put("token", credential.idToken)
    credential.nonce?.let { idToken.put("nonce", it) }
    val body = JSONObject()
      .put("provider", credential.provider.wireName)
      .put("idToken", idToken)

    val response = request(
      path = "/api/auth/sign-in/social",
      method = "POST",
      body = body,
    )
    val bearerToken = BetterAuthBearerToken(
      checkNotNull(response.bearerToken) {
        "Better Auth did not return a bearer token"
      },
    )
    return BetterAuthSession(
      bearerToken = bearerToken,
      convexToken = convexToken(bearerToken),
    )
  }

  suspend fun convexToken(bearerToken: BetterAuthBearerToken): ConvexJwt =
    ConvexJwt(
      JSONObject(
        request(
          path = "/api/auth/convex/token",
          bearerToken = bearerToken,
        ).body,
      ).getString("token"),
    )

  suspend fun signOut(bearerToken: BetterAuthBearerToken) {
    request(
      path = "/api/auth/sign-out",
      method = "POST",
      body = JSONObject(),
      bearerToken = bearerToken,
    )
  }

  private suspend fun request(
    path: String,
    method: String = "GET",
    body: JSONObject? = null,
    bearerToken: BetterAuthBearerToken? = null,
  ): Response = withContext(Dispatchers.IO) {
    val connection = URL("$siteUrl$path").openConnection() as HttpURLConnection
    try {
      connection.requestMethod = method
      connection.setRequestProperty("accept", "application/json")
      bearerToken?.let {
        connection.setRequestProperty("authorization", "Bearer ${it.value}")
      }
      body?.let {
        connection.doOutput = true
        connection.setRequestProperty("content-type", "application/json")
        connection.outputStream.bufferedWriter().use { writer ->
          writer.write(it.toString())
        }
      }

      val status = connection.responseCode
      val responseBody = (if (status in 200..299) {
        connection.inputStream
      } else {
        connection.errorStream
      })?.bufferedReader()?.use { it.readText() }.orEmpty()
      if (status !in 200..299) {
        throw BetterAuthRequestException(status, responseBody)
      }
      Response(
        body = responseBody,
        bearerToken = connection.getHeaderField("set-auth-token"),
      )
    } finally {
      connection.disconnect()
    }
  }

  private data class Response(
    val body: String,
    val bearerToken: String?,
  )
}

class BetterAuthConvexProvider(
  private val nativeIdentity: NativeIdentityProvider,
  private val authClient: BetterAuthNativeClient,
  private val tokenStore: BetterAuthBearerTokenStore,
) : AuthProvider<BetterAuthSession> {
  override suspend fun login(
    context: Context,
    onIdToken: (String?) -> Unit,
  ): Result<BetterAuthSession> = runCatching {
    val session = authClient.signIn(nativeIdentity.signIn(context))
    tokenStore.save(session.bearerToken)
    onIdToken(session.convexToken.value)
    session
  }

  override suspend fun loginFromCache(
    onIdToken: (String?) -> Unit,
  ): Result<BetterAuthSession> = runCatching {
    val bearerToken = checkNotNull(tokenStore.load()) {
      "No cached authentication session is available"
    }
    val session = BetterAuthSession(
      bearerToken = bearerToken,
      convexToken = authClient.convexToken(bearerToken),
    )
    onIdToken(session.convexToken.value)
    session
  }

  override suspend fun logout(context: Context): Result<Void?> = runCatching {
    tokenStore.load()?.let { authClient.signOut(it) }
    tokenStore.clear()
    nativeIdentity.signOut(context)
    null
  }

  override fun extractIdToken(authResult: BetterAuthSession): String =
    authResult.convexToken.value
}
