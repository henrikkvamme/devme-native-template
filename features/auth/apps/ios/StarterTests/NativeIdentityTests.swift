import XCTest
@testable import Starter

final class NativeIdentityTests: XCTestCase {
  func testAppleNonceUsesSHA256HexEncoding() {
    let nonce = IdentityNonce(rawValue: "test")

    XCTAssertEqual(
      nonce.hashedValue,
      "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
    )
  }

  func testGeneratedNonceUsesTheRequestedLengthAndSafeAlphabet() throws {
    let nonce = try IdentityNonce.generate(length: 48)

    XCTAssertEqual(nonce.rawValue.count, 48)
    XCTAssertTrue(nonce.rawValue.allSatisfy(IdentityNonce.allowedCharacters.contains))
  }

  func testProviderNotFoundBecomesAConciseProviderSpecificMessage() {
    let error = BetterAuthNativeError.requestFailed(
      status: 404,
      message: #"{"message":"Provider not found","code":"PROVIDER_NOT_FOUND"}"#
    )

    XCTAssertEqual(
      AuthenticationErrorPresentation.message(for: error, provider: .apple),
      "Apple sign-in is not configured."
    )
  }

  func testNetworkFailureBecomesAnActionableMessage() {
    XCTAssertEqual(
      AuthenticationErrorPresentation.message(
        for: URLError(.notConnectedToInternet),
        provider: .google
      ),
      "Check your internet connection and try again."
    )
  }

  func testAuthenticatedViewerAcceptsASecureProfileImage() throws {
    let viewer = try JSONDecoder().decode(
      AuthenticatedViewer.self,
      from: Data(
        #"{"subject":"user","name":"Profile User","email":"user@example.test","image":"https://example.com/profile.png"}"#.utf8
      )
    )

    XCTAssertEqual(viewer.imageURL?.absoluteString, "https://example.com/profile.png")
  }

  func testAuthenticatedViewerRejectsAnInsecureProfileImage() throws {
    let viewer = try JSONDecoder().decode(
      AuthenticatedViewer.self,
      from: Data(
        #"{"subject":"user","name":null,"email":null,"image":"http://example.com/profile.png"}"#.utf8
      )
    )

    XCTAssertNil(viewer.imageURL)
  }
}
