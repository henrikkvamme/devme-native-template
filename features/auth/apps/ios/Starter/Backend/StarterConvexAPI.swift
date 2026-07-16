import Combine
@preconcurrency import ConvexMobile
import Foundation

struct BootstrapEvent: Codable, Equatable, Identifiable, Sendable {
  let _creationTime: Double
  let _id: String
  let authenticated: Bool?
  let client: String
  let message: String

  var id: String { _id }
  var clientName: String { client == "ios" ? "iOS" : client.capitalized }

  var authenticationLabel: String {
    switch authenticated {
    case true?:
      "Authenticated"
    case false?:
      "Not authenticated"
    case nil:
      "Authentication unknown"
    }
  }

  var authenticationSymbol: String {
    switch authenticated {
    case true?:
      "checkmark.shield.fill"
    case false?:
      "person.crop.circle.badge.xmark"
    case nil:
      "questionmark.circle"
    }
  }
}

struct AuthenticatedViewer: Codable, Equatable, Sendable {
  let subject: String
  let name: String?
  let email: String?
  let image: String?

  var imageURL: URL? {
    guard
      let image,
      let url = URL(string: image),
      url.scheme == "https"
    else { return nil }
    return url
  }
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

enum StarterAuthenticationMode: Equatable, Sendable {
  case native
  case developmentDemo
}

@MainActor
protocol StarterBackend {
  var authenticationMode: StarterAuthenticationMode { get }
  func bootstrapEvents() -> AnyPublisher<[BootstrapEvent], Error>
  func ping() async throws
  func restoreSession() async throws -> AuthenticatedViewer?
  func signIn(with credential: NativeIdentityCredential?) async throws -> AuthenticatedViewer
  func signOut() async
  func deleteAccount() async throws
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
  private let nativeSignInMethod: NativeCredentialSignInMethod?
  let authenticationMode: StarterAuthenticationMode

  init(
    deploymentURL: URL,
    authProvider: BetterAuthProvider,
    authenticationMode: StarterAuthenticationMode,
    nativeSignInMethod: NativeCredentialSignInMethod? = nil
  ) {
    self.authProvider = authProvider
    self.authenticationMode = authenticationMode
    self.nativeSignInMethod = nativeSignInMethod
    client = ConvexClientWithAuth(
      deploymentUrl: deploymentURL.absoluteString,
      authProvider: authProvider
    )
  }

  func bootstrapEvents() -> AnyPublisher<[BootstrapEvent], Error> {
    Self.adaptSubscription(
      client.subscribe(to: Function.bootstrapList, yielding: [BootstrapEvent].self)
    )
  }

  static func adaptSubscription<Output, Failure: Error>(
    _ publisher: AnyPublisher<Output, Failure>
  ) -> AnyPublisher<Output, Error> {
    publisher
      .receive(on: DispatchQueue.main)
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

  func signIn(with credential: NativeIdentityCredential?) async throws -> AuthenticatedViewer {
    if let credential {
      guard let nativeSignInMethod else {
        throw BetterAuthNativeError.providerNotConfigured
      }
      await nativeSignInMethod.prepare(credential)
    }
    switch await client.login() {
    case .success:
      return try await currentViewer()
    case let .failure(error):
      throw StarterBackendError.authenticationFailed(error.localizedDescription)
    }
  }

  func signOut() async {
    await client.logout()
    NativeIdentityClient.signOutFromGoogle()
  }

  func deleteAccount() async throws {
    try await authProvider.deleteUser()
    await client.logout()
    NativeIdentityClient.signOutFromGoogle()
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
