import SwiftUI

struct RootTabView: View {
  @StateObject private var viewModel: HomeViewModel

  init(backend: StarterBackend) {
    _viewModel = StateObject(wrappedValue: HomeViewModel(backend: backend))
  }

  var body: some View {
    TabView {
      NavigationStack {
        HomeView(viewModel: viewModel)
      }
      .tabItem {
        Label("Home", systemImage: "house.fill")
      }

      NavigationStack {
        SettingsView(viewModel: viewModel)
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
    }
    .task { await viewModel.start() }
    .onOpenURL { url in
      if NativeIdentityClient.handleGoogleRedirect(url) { return }
      Task { await viewModel.handleBillingCallback(url) }
    }
  }
}
