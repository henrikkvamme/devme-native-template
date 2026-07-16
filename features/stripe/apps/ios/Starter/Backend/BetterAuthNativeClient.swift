import Foundation
@preconcurrency import ConvexMobile
import Security

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

struct BetterAuthSubscription: Decodable, Equatable, Sendable {
  let id: String
  let plan: String
  let status: String
  let billingInterval: String?
  let cancelAtPeriodEnd: Bool
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

protocol BetterAuthSignInMethod: Sendable {
  func signIn(using authClient: BetterAuthNativeClient) async throws -> BetterAuthSession
  func signOut() async throws
}

actor NativeCredentialSignInMethod: BetterAuthSignInMethod {
  private var pendingCredential: NativeIdentityCredential?

  func prepare(_ credential: NativeIdentityCredential) {
    pendingCredential = credential
  }

  func signIn(using authClient: BetterAuthNativeClient) async throws -> BetterAuthSession {
    guard let credential = pendingCredential else {
      throw BetterAuthNativeError.missingNativeCredential
    }
    pendingCredential = nil
    return try await authClient.signIn(with: credential)
  }

  func signOut() async throws {}
}

struct NativeIdentitySignInMethod: BetterAuthSignInMethod {
  let nativeIdentity: any NativeIdentityProvider

  func signIn(using authClient: BetterAuthNativeClient) async throws -> BetterAuthSession {
    try await authClient.signIn(with: nativeIdentity.signIn())
  }

  func signOut() async throws {
    try await nativeIdentity.signOut()
  }
}

#if DEBUG
struct DevelopmentEmailSignInMethod: BetterAuthSignInMethod {
  let email: String
  let password: String
  let name: String

  func signIn(using authClient: BetterAuthNativeClient) async throws -> BetterAuthSession {
    try await authClient.signInOrSignUp(email: email, password: password, name: name)
  }

  func signOut() async throws {}
}
#endif

struct UnavailableBetterAuthSignInMethod: BetterAuthSignInMethod {
  func signIn(using authClient: BetterAuthNativeClient) async throws -> BetterAuthSession {
    throw BetterAuthNativeError.providerNotConfigured
  }

  func signOut() async throws {}
}

enum BetterAuthNativeError: LocalizedError {
  case invalidResponse
  case missingBearerToken
  case missingNativeCredential
  case noCachedSession
  case providerNotConfigured
  case requestFailed(status: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The authentication server returned an invalid response."
    case .missingBearerToken:
      "The authentication server did not create a bearer session."
    case .missingNativeCredential:
      "Choose Apple or Google before starting authentication."
    case .noCachedSession:
      "No cached authentication session is available."
    case .providerNotConfigured:
      "Configure an Apple or Google identity provider for release builds."
    case let .requestFailed(status, message):
      "Authentication failed with status \(status): \(message)"
    }
  }
}

actor BetterAuthNativeClient {
  private struct TokenResponse: Decodable {
    let token: String
  }

  private struct CheckoutResponse: Decodable {
    let url: URL
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
    return try await session(from: response)
  }

  func signInOrSignUp(email: String, password: String, name: String) async throws
    -> BetterAuthSession
  {
    do {
      let (_, response) = try await request(
        path: "/api/auth/sign-in/email",
        method: "POST",
        json: ["email": email, "password": password]
      )
      return try await session(from: response)
    } catch let BetterAuthNativeError.requestFailed(status, _) where (400..<500).contains(status) {
      let (_, response) = try await request(
        path: "/api/auth/sign-up/email",
        method: "POST",
        json: ["email": email, "password": password, "name": name]
      )
      return try await session(from: response)
    }
  }

  private func session(from response: HTTPURLResponse) async throws -> BetterAuthSession {
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

  func subscriptions(using bearerToken: BetterAuthBearerToken) async throws
    -> [BetterAuthSubscription]
  {
    let (data, _) = try await request(
      path: "/api/auth/subscription/list",
      bearerToken: bearerToken
    )
    return try JSONDecoder().decode([BetterAuthSubscription].self, from: data)
  }

  func subscriptionCheckoutURL(
    using bearerToken: BetterAuthBearerToken,
    plan: String
  ) async throws -> URL {
    let (data, _) = try await request(
      path: "/api/auth/subscription/upgrade",
      method: "POST",
      json: [
        "plan": plan,
        "successUrl": "starter://billing/success",
        "cancelUrl": "starter://billing/cancel",
        "disableRedirect": true,
      ],
      bearerToken: bearerToken
    )
    return try JSONDecoder().decode(CheckoutResponse.self, from: data).url
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
      request.setValue(siteURL.absoluteString, forHTTPHeaderField: "origin")
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

enum KeychainBearerTokenStoreError: LocalizedError {
  case unexpectedStatus(OSStatus)

  var errorDescription: String? {
    switch self {
    case let .unexpectedStatus(status):
      "Keychain operation failed with status \(status)."
    }
  }
}

actor KeychainBearerTokenStore: BetterAuthBearerTokenStore {
  private let service: String
  private let account: String

  init(service: String, account: String = "better-auth-bearer") {
    self.service = service
    self.account = account
  }

  func load() async throws -> BetterAuthBearerToken? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else {
      throw KeychainBearerTokenStoreError.unexpectedStatus(status)
    }
    guard
      let data = item as? Data,
      let rawValue = String(data: data, encoding: .utf8)
    else {
      throw BetterAuthNativeError.invalidResponse
    }
    return BetterAuthBearerToken(rawValue: rawValue)
  }

  func save(_ token: BetterAuthBearerToken) async throws {
    let data = Data(token.rawValue.utf8)
    let updateStatus = SecItemUpdate(
      baseQuery as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw KeychainBearerTokenStoreError.unexpectedStatus(updateStatus)
    }

    var item = baseQuery
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(item as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw KeychainBearerTokenStoreError.unexpectedStatus(addStatus)
    }
  }

  func clear() async throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainBearerTokenStoreError.unexpectedStatus(status)
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

final class BetterAuthProvider: AuthProvider, @unchecked Sendable {
  typealias T = BetterAuthSession

  private let signInMethod: any BetterAuthSignInMethod
  private let authClient: BetterAuthNativeClient
  private let tokenStore: any BetterAuthBearerTokenStore

  init(
    signInMethod: any BetterAuthSignInMethod,
    authClient: BetterAuthNativeClient,
    tokenStore: any BetterAuthBearerTokenStore
  ) {
    self.signInMethod = signInMethod
    self.authClient = authClient
    self.tokenStore = tokenStore
  }

  func login(
    onIdToken: @Sendable @escaping (String?) -> Void
  ) async throws -> BetterAuthSession {
    let session = try await signInMethod.signIn(using: authClient)
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
    try await signInMethod.signOut()
  }

  func subscriptions() async throws -> [BetterAuthSubscription] {
    guard let bearerToken = try await tokenStore.load() else {
      throw BetterAuthNativeError.noCachedSession
    }
    return try await authClient.subscriptions(using: bearerToken)
  }

  func subscriptionCheckoutURL(plan: String) async throws -> URL {
    guard let bearerToken = try await tokenStore.load() else {
      throw BetterAuthNativeError.noCachedSession
    }
    return try await authClient.subscriptionCheckoutURL(using: bearerToken, plan: plan)
  }

  func extractIdToken(from authResult: BetterAuthSession) -> String {
    authResult.convexToken.rawValue
  }
}
