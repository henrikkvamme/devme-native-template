import Combine
@preconcurrency import ConvexMobile
import Foundation

struct BootstrapEvent: Codable, Equatable, Identifiable, Sendable {
  let _creationTime: Double
  let _id: String
  let client: String
  let message: String

  var id: String { _id }
  var clientName: String { client == "ios" ? "iOS" : client.capitalized }
}

@MainActor
protocol SambuBackend {
  func bootstrapEvents() -> AnyPublisher<[BootstrapEvent], Error>
  func ping() async throws
}

@MainActor
final class LiveSambuConvexAPI: SambuBackend {
  private enum Function {
    static let bootstrapList = "bootstrap:list"
    static let bootstrapPing = "bootstrap:ping"
  }

  private let client: ConvexClient

  init(deploymentURL: URL) {
    client = ConvexClient(deploymentUrl: deploymentURL.absoluteString)
  }

  func bootstrapEvents() -> AnyPublisher<[BootstrapEvent], Error> {
    client
      .subscribe(to: Function.bootstrapList, yielding: [BootstrapEvent].self)
      .mapError { $0 as Error }
      .eraseToAnyPublisher()
  }

  func ping() async throws {
    let _: String = try await client.mutation(
      Function.bootstrapPing,
      with: ["client": "ios"]
    )
  }
}
