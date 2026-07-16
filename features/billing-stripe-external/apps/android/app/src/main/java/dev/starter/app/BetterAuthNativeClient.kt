package dev.starter.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.NoCredentialException
import androidx.core.content.edit
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import dev.convex.android.AuthProvider
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.json.JSONArray
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
value class ConvexJwt(val value: String) {
  val subject: String
    get() {
      val payload = value.split('.').getOrNull(1) ?: error("Convex JWT is malformed")
      val decoded = java.util.Base64.getUrlDecoder().decode(payload)
      return Json.parseToJsonElement(decoded.toString(Charsets.UTF_8))
        .jsonObject.getValue("sub").jsonPrimitive.content
    }
}

data class BetterAuthSession(
  val bearerToken: BetterAuthBearerToken,
  val convexToken: ConvexJwt,
) {
  val subject: String
    get() = convexToken.subject
}

data class BetterAuthSubscription(val status: String) {
  val isActive: Boolean
    get() = status == "active" || status == "trialing"
}

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

  suspend fun subscriptions(bearerToken: BetterAuthBearerToken): List<BetterAuthSubscription> {
    val payload = JSONArray(request(
      path = "/api/auth/subscription/list",
      bearerToken = bearerToken,
    ).body)
    return List(payload.length()) { index ->
      BetterAuthSubscription(payload.getJSONObject(index).getString("status"))
    }
  }

  suspend fun subscriptionCheckoutUrl(bearerToken: BetterAuthBearerToken): String =
    JSONObject(
      request(
        path = "/api/auth/subscription/upgrade",
        method = "POST",
        body = JSONObject()
          .put("plan", "starter")
          .put("successUrl", "starter://billing/success")
          .put("cancelUrl", "starter://billing/cancel")
          .put("disableRedirect", true),
        bearerToken = bearerToken,
      ).body,
    ).getString("url")

  suspend fun billingPortalUrl(bearerToken: BetterAuthBearerToken): String =
    JSONObject(
      request(
        path = "/api/auth/subscription/billing-portal",
        method = "POST",
        body = JSONObject()
          .put("returnUrl", "starter://billing/return")
          .put("disableRedirect", true),
        bearerToken = bearerToken,
      ).body,
    ).getString("url")

  suspend fun signOut(bearerToken: BetterAuthBearerToken) {
    request(
      path = "/api/auth/sign-out",
      method = "POST",
      body = JSONObject(),
      bearerToken = bearerToken,
    )
  }

  suspend fun deleteUser(bearerToken: BetterAuthBearerToken) {
    request(
      path = "/api/auth/delete-user",
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

class GoogleCredentialIdentityProvider(
  private val serverClientId: String,
) : NativeIdentityProvider {
  override suspend fun signIn(context: Context): NativeIdentityCredential {
    check(serverClientId.isNotBlank()) {
      "Set the googleWebClientId Gradle property to the Google web OAuth client ID"
    }
    val option = GetSignInWithGoogleOption.Builder(serverClientId).build()
    val result = try {
      CredentialManager.create(context).getCredential(
        context = context,
        request = GetCredentialRequest.Builder().addCredentialOption(option).build(),
      )
    } catch (_: NoCredentialException) {
      error("No Google account is available for sign-in")
    }
    val credential = result.credential
    check(
      credential is CustomCredential &&
        credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL,
    ) { "Google returned an unsupported credential type" }
    return NativeIdentityCredential(
      provider = NativeSocialProvider.Google,
      idToken = GoogleIdTokenCredential.createFrom(credential.data).idToken,
    )
  }

  override suspend fun signOut(context: Context) {
    CredentialManager.create(context).clearCredentialState(ClearCredentialStateRequest())
  }
}

class AndroidKeystoreBearerTokenStore(context: Context) : BetterAuthBearerTokenStore {
  private val preferences = context.getSharedPreferences("better-auth-session", Context.MODE_PRIVATE)

  override suspend fun load(): BetterAuthBearerToken? {
    val encoded = preferences.getString(TOKEN_KEY, null) ?: return null
    val payload = Base64.decode(encoded, Base64.NO_WRAP)
    check(payload.size > IV_LENGTH) { "Stored authentication session is invalid" }
    val cipher = Cipher.getInstance(TRANSFORMATION)
    cipher.init(
      Cipher.DECRYPT_MODE,
      encryptionKey(),
      GCMParameterSpec(128, payload.copyOfRange(0, IV_LENGTH)),
    )
    val plaintext = cipher.doFinal(payload.copyOfRange(IV_LENGTH, payload.size))
    return BetterAuthBearerToken(plaintext.toString(Charsets.UTF_8))
  }

  override suspend fun save(token: BetterAuthBearerToken) {
    val cipher = Cipher.getInstance(TRANSFORMATION)
    cipher.init(Cipher.ENCRYPT_MODE, encryptionKey())
    val encrypted = cipher.doFinal(token.value.toByteArray(Charsets.UTF_8))
    preferences.edit {
      putString(TOKEN_KEY, Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP))
    }
  }

  override suspend fun clear() {
    preferences.edit { remove(TOKEN_KEY) }
  }

  private fun encryptionKey(): SecretKey {
    val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
    return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
      init(
        KeyGenParameterSpec.Builder(
          KEY_ALIAS,
          KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
          .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
          .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
          .build(),
      )
      generateKey()
    }
  }

  private companion object {
    const val KEY_ALIAS = "starter-better-auth-bearer"
    const val TOKEN_KEY = "encrypted-bearer"
    const val TRANSFORMATION = "AES/GCM/NoPadding"
    const val IV_LENGTH = 12
  }
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

  suspend fun reauthenticate(context: Context): BetterAuthSession {
    val freshSession = authClient.signIn(nativeIdentity.signIn(context))
    tokenStore.save(freshSession.bearerToken)
    return freshSession
  }

  suspend fun deleteUser(context: Context, session: BetterAuthSession) {
    authClient.deleteUser(session.bearerToken)
    tokenStore.clear()
    nativeIdentity.signOut(context)
  }

  suspend fun subscriptions(): List<BetterAuthSubscription> =
    authClient.subscriptions(requireBearerToken())

  suspend fun subscriptionCheckoutUrl(): String =
    authClient.subscriptionCheckoutUrl(requireBearerToken())

  suspend fun billingPortalUrl(): String =
    authClient.billingPortalUrl(requireBearerToken())

  private suspend fun requireBearerToken(): BetterAuthBearerToken =
    checkNotNull(tokenStore.load()) { "No cached authentication session is available" }

  override fun extractIdToken(authResult: BetterAuthSession): String =
    authResult.convexToken.value
}
