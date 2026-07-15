import SwiftUI

struct HomeView: View {
  @ObservedObject var viewModel: HomeViewModel

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
              HStack(spacing: 8) {
                Text(event.clientName)
                Text("•")
                  .accessibilityHidden(true)
                Label(event.authenticationLabel, systemImage: event.authenticationSymbol)
                  .foregroundStyle(event.authenticated == true ? .green : .secondary)
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle("Starter")
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
