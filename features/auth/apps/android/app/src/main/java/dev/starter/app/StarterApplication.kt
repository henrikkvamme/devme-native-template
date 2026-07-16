package dev.starter.app

import android.app.Application
import dev.convex.android.ConvexClientWithAuth

class StarterApplication : Application() {
  private val authProvider: BetterAuthConvexProvider by lazy {
    BetterAuthConvexProvider(
      nativeIdentity = GoogleCredentialIdentityProvider(BuildConfig.GOOGLE_WEB_CLIENT_ID),
      authClient = BetterAuthNativeClient(BuildConfig.AUTH_SITE_URL),
      tokenStore = AndroidKeystoreBearerTokenStore(this),
    )
  }

  private val client: ConvexClientWithAuth<BetterAuthSession> by lazy {
    ConvexClientWithAuth(BuildConfig.CONVEX_URL, authProvider)
  }

  val backend: StarterBackend by lazy {
    LiveStarterConvexApi(client)
  }

  val authentication: AuthenticationController by lazy {
    AuthenticationController(client, authProvider)
  }
}
