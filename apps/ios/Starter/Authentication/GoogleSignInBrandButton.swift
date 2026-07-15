import GoogleSignIn
import SwiftUI
import UIKit

struct GoogleSignInBrandButton: View {
  @Environment(\.displayScale) private var displayScale
  let isAuthenticating: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Text("Sign in with Google")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))

        HStack {
          GoogleBrandIcon()
            .frame(width: 20, height: 20)
          Spacer()
        }
        .padding(.leading, 16)
      }
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
    .buttonStyle(GoogleBrandButtonStyle())
    .disabled(isAuthenticating)
    .accessibilityLabel("Sign in with Google")
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

private struct GoogleBrandButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
  }
}
