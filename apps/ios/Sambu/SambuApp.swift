import SwiftUI

@main
struct SambuApp: App {
  var body: some Scene {
    WindowGroup {
      RootTabView(
        backend: LiveSambuConvexAPI(
          deploymentURL: AppConfiguration.convexURL
        )
      )
    }
  }
}
