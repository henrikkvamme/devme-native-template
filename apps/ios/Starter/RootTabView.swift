import SwiftUI

struct RootTabView: View {
  let backend: StarterBackend

  var body: some View {
    TabView {
      NavigationStack {
        HomeView(backend: backend)
      }
      .tabItem {
        Label("Home", systemImage: "house.fill")
      }

      NavigationStack {
        PlaceholderView(
          title: "Activity",
          systemImage: "clock.arrow.circlepath"
        )
      }
      .tabItem {
        Label("Activity", systemImage: "clock.arrow.circlepath")
      }

      NavigationStack {
        PlaceholderView(
          title: "Settings",
          systemImage: "gearshape.fill"
        )
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
    }
  }
}

private struct PlaceholderView: View {
  let title: String
  let systemImage: String

  var body: some View {
    ContentUnavailableView(
      title,
      systemImage: systemImage,
      description: Text("Replace this tab with your native feature.")
    )
    .navigationTitle(title)
  }
}
