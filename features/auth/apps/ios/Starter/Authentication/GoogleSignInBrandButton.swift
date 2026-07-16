import AuthenticationServices
import GoogleSignIn
import SwiftUI
import UIKit

struct AppleSignInBrandButton: View {
  @StateObject private var coordinator = AppleAuthorizationCoordinator()
  let isAuthenticating: Bool
  let onRequest: (ASAuthorizationAppleIDRequest) -> Void
  let onCompletion: (Result<ASAuthorization, Error>) -> Void

  var body: some View {
    IdentityProviderButton(
      title: "Sign in with Apple",
      isAuthenticating: isAuthenticating,
      icon: {
        Image(systemName: "apple.logo")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.black)
          .accessibilityHidden(true)
      },
      action: {
        coordinator.start(onRequest: onRequest, onCompletion: onCompletion)
      }
    )
  }
}

struct GoogleSignInBrandButton: View {
  let isAuthenticating: Bool
  let action: () -> Void

  var body: some View {
    IdentityProviderButton(
      title: "Sign in with Google",
      isAuthenticating: isAuthenticating,
      icon: { GoogleBrandIcon() },
      action: action
    )
  }
}

private struct IdentityProviderButton<Icon: View>: View {
  @Environment(\.displayScale) private var displayScale
  let title: String
  let isAuthenticating: Bool
  @ViewBuilder let icon: () -> Icon
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        icon()
          .frame(width: 20, height: 20)

        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(.white)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            Color(red: 116 / 255, green: 119 / 255, blue: 117 / 255),
            lineWidth: 1 / displayScale
          )
      }
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(IdentityProviderButtonStyle())
    .disabled(isAuthenticating)
    .accessibilityLabel(title)
  }
}

@MainActor
private final class AppleAuthorizationCoordinator: NSObject, ObservableObject {
  private var authorizationController: ASAuthorizationController?
  private var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

  func start(
    onRequest: (ASAuthorizationAppleIDRequest) -> Void,
    onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
  ) {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    onRequest(request)

    self.onCompletion = onCompletion
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    authorizationController = controller
    controller.performRequests()
  }

  private func finish(_ result: Result<ASAuthorization, Error>) {
    onCompletion?(result)
    onCompletion = nil
    authorizationController = nil
  }
}

extension AppleAuthorizationCoordinator: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    finish(.success(authorization))
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    finish(.failure(error))
  }
}

extension AppleAuthorizationCoordinator: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
  }
}

private struct GoogleBrandIcon: View {
  private static let image: UIImage? = {
    let bundles = [Bundle.main, Bundle(for: GIDSignIn.self)]
    for parent in bundles {
      guard
        let path = parent.path(forResource: "GoogleSignIn_GoogleSignIn", ofType: "bundle"),
        let resources = Bundle(path: path),
        let url = resources.url(forResource: "google", withExtension: "png"),
        let image = UIImage(contentsOfFile: url.path)
      else { continue }
      return image
    }
    return nil
  }()

  var body: some View {
    if let image = Self.image {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .accessibilityHidden(true)
    }
  }
}

private struct IdentityProviderButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
  }
}
