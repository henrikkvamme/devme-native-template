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

struct AuthenticatedViewer: Codable, Equatable, Sendable {
  let subject: String
  let name: String?
  let email: String?
}

enum StarterBackendError: LocalizedError {
  case authenticationFailed(String)
  case missingAuthenticatedViewer

  var errorDescription: String? {
    switch self {
    case let .authenticationFailed(message):
      "Authentication failed: \(message)"
    case .missingAuthenticatedViewer:
      "Convex did not resolve the authenticated user."
    }
  }
}

@MainActor
protocol StarterBackend {
  func bootstrapEvents() -> AnyPublisher<[BootstrapEvent], Error>
  func ping() async throws
  func restoreSession() async throws -> AuthenticatedViewer?
  func signIn() async throws -> AuthenticatedViewer
  func signOut() async
  func subscriptions() async throws -> [BetterAuthSubscription]
  func subscriptionCheckoutURL() async throws -> URL
}

@MainActor
final class LiveStarterConvexAPI: StarterBackend {
  private enum Function {
    static let bootstrapList = "bootstrap:list"
    static let bootstrapPing = "bootstrap:ping"
    static let currentViewer = "auth:current"
  }

  private let client: ConvexClientWithAuth<BetterAuthSession>
  private let authProvider: BetterAuthProvider

  init(deploymentURL: URL, authProvider: BetterAuthProvider) {
    self.authProvider = authProvider
    client = ConvexClientWithAuth(
      deploymentUrl: deploymentURL.absoluteString,
      authProvider: authProvider
    )
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

  func restoreSession() async throws -> AuthenticatedViewer? {
    switch await client.loginFromCache() {
    case .success:
      return try await currentViewer()
    case .failure:
      return nil
    }
  }

  func signIn() async throws -> AuthenticatedViewer {
    switch await client.login() {
    case .success:
      return try await currentViewer()
    case let .failure(error):
      throw StarterBackendError.authenticationFailed(error.localizedDescription)
    }
  }

  func signOut() async {
    await client.logout()
  }

  func subscriptions() async throws -> [BetterAuthSubscription] {
    try await authProvider.subscriptions()
  }

  func subscriptionCheckoutURL() async throws -> URL {
    try await authProvider.subscriptionCheckoutURL(plan: "starter")
  }

  private func currentViewer() async throws -> AuthenticatedViewer {
    let publisher = client.subscribe(
      to: Function.currentViewer,
      yielding: AuthenticatedViewer?.self
    )
    for try await viewer in publisher.values {
      guard let viewer else { throw StarterBackendError.missingAuthenticatedViewer }
      return viewer
    }
    throw StarterBackendError.missingAuthenticatedViewer
  }
}
