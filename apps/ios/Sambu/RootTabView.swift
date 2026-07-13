import SwiftUI

struct RootTabView: View {
  let backend: SambuBackend

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
          title: "Shopping",
          systemImage: "cart.fill"
        )
      }
      .tabItem {
        Label("Shopping", systemImage: "cart.fill")
      }

      NavigationStack {
        PlaceholderView(
          title: "Chores",
          systemImage: "checklist"
        )
      }
      .tabItem {
        Label("Chores", systemImage: "checklist")
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
      description: Text("This feature will be implemented as a native flow.")
    )
    .navigationTitle(title)
  }
}
