import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
  enum ConnectionState: Equatable {
    case connecting
    case connected
    case failed(String)
  }

  @Published private(set) var connectionState: ConnectionState = .connecting
  @Published private(set) var events: [BootstrapEvent] = []
  @Published private(set) var isSendingPing = false

  private let backend: StarterBackend
  private var subscription: AnyCancellable?

  init(backend: StarterBackend) {
    self.backend = backend
  }

  func start() {
    guard subscription == nil else { return }

    subscription = backend
      .bootstrapEvents()
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          guard case let .failure(error) = completion else { return }
          self?.connectionState = .failed(error.localizedDescription)
        },
        receiveValue: { [weak self] events in
          self?.events = events
          self?.connectionState = .connected
        }
      )
  }

  func sendPing() async {
    guard !isSendingPing else { return }
    isSendingPing = true
    defer { isSendingPing = false }

    do {
      try await backend.ping()
    } catch {
      connectionState = .failed(error.localizedDescription)
    }
  }
}
