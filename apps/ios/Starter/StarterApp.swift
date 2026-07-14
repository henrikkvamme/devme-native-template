import SwiftUI

@main
struct StarterApp: App {
  private let backend: StarterBackend

  init() {
    let authClient = BetterAuthNativeClient(siteURL: AppConfiguration.authSiteURL)
    let tokenStore = KeychainBearerTokenStore(service: "dev.starter.app.better-auth")
#if DEBUG
    let signInMethod: any BetterAuthSignInMethod = DevelopmentEmailSignInMethod(
      email: "native-starter-demo@example.test",
      password: "Local-only-native-demo-2026!",
      name: "Native Starter Developer"
    )
#else
    let signInMethod: any BetterAuthSignInMethod = UnavailableBetterAuthSignInMethod()
#endif
    let authProvider = BetterAuthProvider(
      signInMethod: signInMethod,
      authClient: authClient,
      tokenStore: tokenStore
    )
    backend = LiveStarterConvexAPI(
      deploymentURL: AppConfiguration.convexURL,
      authProvider: authProvider
    )
  }

  var body: some Scene {
    WindowGroup {
      RootTabView(backend: backend)
    }
  }
}
