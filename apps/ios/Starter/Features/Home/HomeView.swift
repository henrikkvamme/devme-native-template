import SwiftUI

struct HomeView: View {
  @Environment(\.openURL) private var openURL
  @StateObject private var viewModel: HomeViewModel

  init(backend: StarterBackend) {
    _viewModel = StateObject(wrappedValue: HomeViewModel(backend: backend))
  }

  var body: some View {
    List {
      Section("Connection") {
        HStack(spacing: 12) {
          Image(systemName: connectionSymbol)
            .foregroundStyle(connectionColor)
          Text(connectionLabel)
        }

        Button {
          Task { await viewModel.sendPing() }
        } label: {
          Label("Send native ping", systemImage: "wave.3.right")
        }
        .disabled(viewModel.isSendingPing)
      }

      Section("Authentication") {
        switch viewModel.authenticationState {
        case .loading:
          HStack(spacing: 12) {
            ProgressView()
            Text("Restoring secure session")
          }
        case .signedOut:
          Label("Signed out", systemImage: "person.crop.circle.badge.xmark")
            .foregroundStyle(.secondary)
          Button {
            Task { await viewModel.signIn() }
          } label: {
            Label("Sign in demo user", systemImage: "person.badge.key.fill")
          }
          .disabled(viewModel.isAuthenticating)
        case let .signedIn(viewer):
          Label("Authenticated Convex identity verified", systemImage: "checkmark.shield.fill")
            .foregroundStyle(.green)
          VStack(alignment: .leading, spacing: 4) {
            Text(viewer.name ?? "Authenticated user")
              .font(.headline)
            if let email = viewer.email {
              Text(email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
          Button("Sign out", role: .destructive) {
            Task { await viewModel.signOut() }
          }
          .disabled(viewModel.isAuthenticating)
        case let .failed(message):
          Label("Authentication failed", systemImage: "exclamationmark.shield.fill")
            .foregroundStyle(.orange)
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Try again") {
            Task { await viewModel.signIn() }
          }
          .disabled(viewModel.isAuthenticating)
        }
      }

      if case .signedIn = viewModel.authenticationState {
        Section("Billing") {
          switch viewModel.billingState {
          case .unavailable, .loading:
            HStack(spacing: 12) {
              ProgressView()
              Text("Loading subscription")
            }
          case .free:
            Label("No active subscription", systemImage: "creditcard")
              .foregroundStyle(.secondary)
            Button {
              Task {
                if let url = await viewModel.beginCheckout() {
                  openURL(url)
                }
              }
            } label: {
              Label("Start Starter plan", systemImage: "arrow.up.right.square")
            }
            .disabled(viewModel.isStartingCheckout)
          case let .active(subscription):
            Label("Starter plan active", systemImage: "checkmark.seal.fill")
              .foregroundStyle(.green)
            Text(subscription.billingInterval == "month" ? "Renews monthly" : "Subscription active")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          case let .failed(message):
            Label("Billing unavailable", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            Text(message)
              .font(.caption)
              .foregroundStyle(.secondary)
            Button("Try again") {
              Task { await viewModel.refreshBilling() }
            }
          }
        }
      }

      Section("Latest events") {
        if viewModel.events.isEmpty {
          ContentUnavailableView(
            "No events yet",
            systemImage: "bolt.horizontal.circle",
            description: Text("Send a ping to verify the reactive connection.")
          )
        } else {
          ForEach(viewModel.events) { event in
            VStack(alignment: .leading, spacing: 4) {
              Text(event.message)
                .font(.headline)
              Text(event.clientName)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle("Starter")
    .task { await viewModel.start() }
    .onOpenURL { url in
      Task { await viewModel.handleBillingCallback(url) }
    }
  }

  private var connectionLabel: String {
    switch viewModel.connectionState {
    case .connecting:
      "Connecting"
    case .connected:
      "Connected to Convex"
    case let .failed(message):
      "Connection failed: \(message)"
    }
  }

  private var connectionSymbol: String {
    switch viewModel.connectionState {
    case .connecting:
      "circle.dotted"
    case .connected:
      "checkmark.circle.fill"
    case .failed:
      "exclamationmark.triangle.fill"
    }
  }

  private var connectionColor: Color {
    switch viewModel.connectionState {
    case .connecting:
      .secondary
    case .connected:
      .green
    case .failed:
      .orange
    }
  }
}
