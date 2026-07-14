import SwiftUI

struct HomeView: View {
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
    .task { viewModel.start() }
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
