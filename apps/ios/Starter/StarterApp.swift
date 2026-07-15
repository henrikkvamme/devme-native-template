import SwiftUI

@main
struct StarterApp: App {
  private let backend: StarterBackend

  init() {
    let authClient = BetterAuthNativeClient(siteURL: AppConfiguration.authSiteURL)
    let tokenStore = KeychainBearerTokenStore(service: "dev.starter.app.better-auth")
#if DEBUG
    if ProcessInfo.processInfo.environment["STARTER_AUTH_MODE"] == "demo" {
      let signInMethod = DevelopmentEmailSignInMethod(
        email: "native-starter-demo@example.test",
        password: "Local-only-native-demo-2026!",
        name: "Native Starter Developer"
      )
      let authProvider = BetterAuthProvider(
        signInMethod: signInMethod,
        authClient: authClient,
        tokenStore: tokenStore
      )
      backend = LiveStarterConvexAPI(
        deploymentURL: AppConfiguration.convexURL,
        authProvider: authProvider,
        authenticationMode: .developmentDemo
      )
      return
    }
#else
#endif
    let signInMethod = NativeCredentialSignInMethod()
    let authProvider = BetterAuthProvider(
      signInMethod: signInMethod,
      authClient: authClient,
      tokenStore: tokenStore
    )
    backend = LiveStarterConvexAPI(
      deploymentURL: AppConfiguration.convexURL,
      authProvider: authProvider,
      authenticationMode: .native,
      nativeSignInMethod: signInMethod
    )
  }

  var body: some Scene {
    WindowGroup {
      RootTabView(backend: backend)
    }
  }
}
