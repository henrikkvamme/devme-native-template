import AuthenticationServices
import Foundation
import GoogleSignIn
import UIKit

enum NativeIdentityError: LocalizedError {
  case missingAppleIdentityToken
  case missingGoogleIdentityToken
  case missingPresentationContext

  var errorDescription: String? {
    switch self {
    case .missingAppleIdentityToken:
      "Apple did not return an identity token."
    case .missingGoogleIdentityToken:
      "Google did not return an identity token."
    case .missingPresentationContext:
      "The Google sign-in screen could not be presented."
    }
  }
}

enum NativeIdentityClient {
  static func isCancellation(_ error: Error) -> Bool {
    let error = error as NSError
    return
      (error.domain == ASAuthorizationError.errorDomain
        && error.code == ASAuthorizationError.canceled.rawValue)
      || (error.domain == kGIDSignInErrorDomain && error.code == -5)
  }

  static func appleCredential(
    from credential: ASAuthorizationAppleIDCredential,
    nonce: IdentityNonce
  ) throws -> NativeIdentityCredential {
    guard
      let identityToken = credential.identityToken,
      let token = String(data: identityToken, encoding: .utf8)
    else {
      throw NativeIdentityError.missingAppleIdentityToken
    }
    return NativeIdentityCredential(provider: .apple, idToken: token, nonce: nonce.rawValue)
  }

  @MainActor
  static func signInWithGoogle() async throws -> NativeIdentityCredential {
    guard let presentingViewController else {
      throw NativeIdentityError.missingPresentationContext
    }

    let result = try await GIDSignIn.sharedInstance.signIn(
      withPresenting: presentingViewController
    )
    if result.user.idToken == nil {
      try await result.user.refreshTokensIfNeeded()
    }
    guard let token = result.user.idToken?.tokenString else {
      throw NativeIdentityError.missingGoogleIdentityToken
    }
    return NativeIdentityCredential(provider: .google, idToken: token, nonce: nil)
  }

  @MainActor
  static func handleGoogleRedirect(_ url: URL) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }

  @MainActor
  static func signOutFromGoogle() {
    GIDSignIn.sharedInstance.signOut()
  }

  @MainActor
  private static var presentingViewController: UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var presenter = window?.rootViewController
    while let presented = presenter?.presentedViewController {
      presenter = presented
    }
    return presenter
  }
}
