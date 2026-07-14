import SwiftUI

@main
struct StarterApp: App {
  var body: some Scene {
    WindowGroup {
      RootTabView(
        backend: LiveStarterConvexAPI(
          deploymentURL: AppConfiguration.convexURL
        )
      )
    }
  }
}
