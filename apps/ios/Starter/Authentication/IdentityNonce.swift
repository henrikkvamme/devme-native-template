import CryptoKit
import Foundation
import Security

struct IdentityNonce: Equatable, Sendable {
  static let allowedCharacters = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
  )

  let rawValue: String

  var hashedValue: String {
    SHA256.hash(data: Data(rawValue.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  static func generate(length: Int = 32) throws -> IdentityNonce {
    precondition(length > 0)

    var randomBytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    guard status == errSecSuccess else {
      throw IdentityNonceError.secureRandomFailed(status)
    }

    let value = randomBytes.map { byte in
      allowedCharacters[Int(byte) % allowedCharacters.count]
    }
    return IdentityNonce(rawValue: String(value))
  }
}

enum IdentityNonceError: LocalizedError {
  case secureRandomFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case let .secureRandomFailed(status):
      "Secure nonce generation failed with status \(status)."
    }
  }
}
