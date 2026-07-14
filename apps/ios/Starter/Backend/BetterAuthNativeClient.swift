import Foundation
@preconcurrency import ConvexMobile

enum NativeSocialProvider: String, Sendable {
  case apple
  case google
}

struct NativeIdentityCredential: Sendable {
  let provider: NativeSocialProvider
  let idToken: String
  let nonce: String?
}

struct BetterAuthBearerToken: Sendable {
  let rawValue: String
}

struct ConvexJWT: Sendable {
  let rawValue: String
}

struct BetterAuthSession: Sendable {
  let bearerToken: BetterAuthBearerToken
  let convexToken: ConvexJWT
}

protocol NativeIdentityProvider: Sendable {
  func signIn() async throws -> NativeIdentityCredential
  func signOut() async throws
}

protocol BetterAuthBearerTokenStore: Sendable {
  func load() async throws -> BetterAuthBearerToken?
  func save(_ token: BetterAuthBearerToken) async throws
  func clear() async throws
}

enum BetterAuthNativeError: LocalizedError {
  case invalidResponse
  case missingBearerToken
  case noCachedSession
  case requestFailed(status: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The authentication server returned an invalid response."
    case .missingBearerToken:
      "The authentication server did not create a bearer session."
    case .noCachedSession:
      "No cached authentication session is available."
    case let .requestFailed(status, message):
      "Authentication failed with status \(status): \(message)"
    }
  }
}

actor BetterAuthNativeClient {
  private struct TokenResponse: Decodable {
    let token: String
  }

  private let siteURL: URL
  private let session: URLSession

  init(siteURL: URL, session: URLSession = .shared) {
    self.siteURL = siteURL
    self.session = session
  }

  func signIn(with credential: NativeIdentityCredential) async throws -> BetterAuthSession {
    var idToken: [String: String] = ["token": credential.idToken]
    if let nonce = credential.nonce {
      idToken["nonce"] = nonce
    }

    let (_, response) = try await request(
      path: "/api/auth/sign-in/social",
      method: "POST",
      json: ["provider": credential.provider.rawValue, "idToken": idToken]
    )
    guard let rawBearerToken = response.value(forHTTPHeaderField: "set-auth-token") else {
      throw BetterAuthNativeError.missingBearerToken
    }
    let bearerToken = BetterAuthBearerToken(rawValue: rawBearerToken)

    return BetterAuthSession(
      bearerToken: bearerToken,
      convexToken: try await convexToken(using: bearerToken)
    )
  }

  func convexToken(using bearerToken: BetterAuthBearerToken) async throws -> ConvexJWT {
    let (data, _) = try await request(
      path: "/api/auth/convex/token",
      bearerToken: bearerToken
    )
    return ConvexJWT(rawValue: try JSONDecoder().decode(TokenResponse.self, from: data).token)
  }

  func subscriptions(using bearerToken: BetterAuthBearerToken) async throws -> Data {
    let (data, _) = try await request(
      path: "/api/auth/subscription/list",
      bearerToken: bearerToken
    )
    return data
  }

  func signOut(using bearerToken: BetterAuthBearerToken) async throws {
    _ = try await request(
      path: "/api/auth/sign-out",
      method: "POST",
      json: [:],
      bearerToken: bearerToken
    )
  }

  private func request(
    path: String,
    method: String = "GET",
    json: [String: Any]? = nil,
    bearerToken: BetterAuthBearerToken? = nil
  ) async throws -> (Data, HTTPURLResponse) {
    var request = URLRequest(url: siteURL.appending(path: path))
    request.httpMethod = method
    if let json {
      request.httpBody = try JSONSerialization.data(withJSONObject: json)
      request.setValue("application/json", forHTTPHeaderField: "content-type")
    }
    if let bearerToken {
      request.setValue("Bearer \(bearerToken.rawValue)", forHTTPHeaderField: "authorization")
    }

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw BetterAuthNativeError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw BetterAuthNativeError.requestFailed(
        status: httpResponse.statusCode,
        message: String(data: data, encoding: .utf8) ?? "Unknown error"
      )
    }
    return (data, httpResponse)
  }
}

final class BetterAuthProvider: AuthProvider, @unchecked Sendable {
  typealias T = BetterAuthSession

  private let nativeIdentity: any NativeIdentityProvider
  private let authClient: BetterAuthNativeClient
  private let tokenStore: any BetterAuthBearerTokenStore

  init(
    nativeIdentity: any NativeIdentityProvider,
    authClient: BetterAuthNativeClient,
    tokenStore: any BetterAuthBearerTokenStore
  ) {
    self.nativeIdentity = nativeIdentity
    self.authClient = authClient
    self.tokenStore = tokenStore
  }

  func login(
    onIdToken: @Sendable @escaping (String?) -> Void
  ) async throws -> BetterAuthSession {
    let credential = try await nativeIdentity.signIn()
    let session = try await authClient.signIn(with: credential)
    try await tokenStore.save(session.bearerToken)
    onIdToken(session.convexToken.rawValue)
    return session
  }

  func loginFromCache(
    onIdToken: @Sendable @escaping (String?) -> Void
  ) async throws -> BetterAuthSession {
    guard let bearerToken = try await tokenStore.load() else {
      throw BetterAuthNativeError.noCachedSession
    }
    let convexToken = try await authClient.convexToken(using: bearerToken)
    let session = BetterAuthSession(
      bearerToken: bearerToken,
      convexToken: convexToken
    )
    onIdToken(convexToken.rawValue)
    return session
  }

  func logout() async throws {
    if let bearerToken = try await tokenStore.load() {
      try await authClient.signOut(using: bearerToken)
    }
    try await tokenStore.clear()
    try await nativeIdentity.signOut()
  }

  func extractIdToken(from authResult: BetterAuthSession) -> String {
    authResult.convexToken.rawValue
  }
}
