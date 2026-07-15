import AuthenticationServices
import SwiftUI

struct SettingsView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.openURL) private var openURL
  @ObservedObject var viewModel: HomeViewModel
  @State private var isConfirmingSignOut = false
  @State private var appleNonce: IdentityNonce?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        profileCard

        if case .signedIn = viewModel.authenticationState {
          subscriptionSection
          accountSection
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 32)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Settings")
    .alert("Sign out?", isPresented: $isConfirmingSignOut) {
      Button("Sign out", role: .destructive) {
        Task { await viewModel.signOut() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your local session will be removed. You can sign in again at any time.")
    }
  }

  @ViewBuilder
  private var profileCard: some View {
    switch viewModel.authenticationState {
    case .loading:
      accountCard {
        HStack(spacing: 16) {
          ProgressView()
            .controlSize(.large)
          VStack(alignment: .leading, spacing: 4) {
            Text("Restoring your session")
              .font(.headline)
            Text("Checking the secure session on this device")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
    case .signedOut:
      accountCard {
        VStack(alignment: .leading, spacing: 18) {
          HStack(spacing: 14) {
            avatar(systemImage: "person.fill", tint: .secondary)
            VStack(alignment: .leading, spacing: 4) {
              Text("Your account")
                .font(.headline)
              Text("Sign in to keep your data and subscription connected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }

          signInControls

          if let message = viewModel.authenticationErrorMessage {
            authenticationError(message)
          }
        }
      }
    case let .signedIn(viewer):
      signedInProfileCard(viewer)
    }
  }

  @ViewBuilder
  private var signInControls: some View {
    switch viewModel.authenticationMode {
    case .developmentDemo:
      Button {
        Task { await viewModel.signIn() }
      } label: {
        Label("Sign in demo user", systemImage: "person.badge.key.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(viewModel.isAuthenticating)

    case .native:
      VStack(spacing: 12) {
        SignInWithAppleButton(.signIn) { request in
          configureAppleRequest(request)
        } onCompletion: { result in
          completeAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(viewModel.isAuthenticating)

        GoogleSignInBrandButton(isAuthenticating: viewModel.isAuthenticating) {
          Task { await signInWithGoogle() }
        }
      }
    }
  }

  private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
    do {
      let nonce = try IdentityNonce.generate()
      appleNonce = nonce
      request.requestedScopes = [.fullName, .email]
      request.nonce = nonce.hashedValue
    } catch {
      viewModel.reportAuthenticationError(error, provider: .apple)
    }
  }

  private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
    defer { appleNonce = nil }
    do {
      let authorization = try result.get()
      guard
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let appleNonce
      else {
        throw NativeIdentityError.missingAppleIdentityToken
      }
      let nativeCredential = try NativeIdentityClient.appleCredential(
        from: credential,
        nonce: appleNonce
      )
      Task { await viewModel.signIn(with: nativeCredential) }
    } catch {
      guard !NativeIdentityClient.isCancellation(error) else { return }
      viewModel.reportAuthenticationError(error, provider: .apple)
    }
  }

  @MainActor
  private func signInWithGoogle() async {
    do {
      let credential = try await NativeIdentityClient.signInWithGoogle()
      await viewModel.signIn(with: credential)
    } catch {
      guard !NativeIdentityClient.isCancellation(error) else { return }
      viewModel.reportAuthenticationError(error, provider: .google)
    }
  }

  private func signedInProfileCard(_ viewer: AuthenticatedViewer) -> some View {
    accountCard {
      HStack(spacing: 14) {
        profileAvatar(for: viewer)

        VStack(alignment: .leading, spacing: 4) {
          Text(viewer.name ?? "Authenticated user")
            .font(.headline)
            .lineLimit(1)

          if let email = viewer.email {
            Text(email)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .textSelection(.enabled)
          }

          Label("Signed in securely", systemImage: "checkmark.shield.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func authenticationError(_ message: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.orange)
      Text(message)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        viewModel.dismissAuthenticationError()
      } label: {
        Image(systemName: "xmark")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss sign-in error")
    }
    .padding(12)
    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }

  private var subscriptionSection: some View {
    settingsSection(title: "Subscription") {
      switch viewModel.billingState {
      case .unavailable, .loading:
        settingsRow(icon: "creditcard.fill", tint: .blue) {
          HStack(spacing: 12) {
            ProgressView()
            Text("Loading subscription")
          }
        }
      case .free:
        VStack(spacing: 0) {
          settingsRow(icon: "creditcard.fill", tint: .blue) {
            VStack(alignment: .leading, spacing: 3) {
              Text("Free plan")
                .font(.body.weight(.semibold))
              Text("No active subscription")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Divider().padding(.leading, 58)

          Button {
            Task {
              if let url = await viewModel.beginCheckout() {
                openURL(url)
              }
            }
          } label: {
            Label("Start Starter plan", systemImage: "arrow.up.right")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(16)
          }
          .disabled(viewModel.isStartingCheckout)
        }
      case let .active(subscription):
        settingsRow(icon: "checkmark.seal.fill", tint: .green) {
          VStack(alignment: .leading, spacing: 3) {
            Text("Starter plan")
              .font(.body.weight(.semibold))
            Text(subscription.billingInterval == "month" ? "Renews monthly" : "Subscription active")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      case let .failed(message):
        settingsRow(icon: "exclamationmark.triangle.fill", tint: .orange) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Billing unavailable")
              .font(.body.weight(.semibold))
            Text(message)
              .font(.caption)
              .foregroundStyle(.secondary)
            Button("Try again") {
              Task { await viewModel.refreshBilling() }
            }
          }
        }
      }
    }
  }

  private var accountSection: some View {
    settingsSection(title: "Account") {
      Button(role: .destructive) {
        isConfirmingSignOut = true
      } label: {
        HStack(spacing: 14) {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .font(.body.weight(.semibold))
            .frame(width: 30, height: 30)
            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
          Text("Sign out")
            .font(.body.weight(.medium))
          Spacer()
        }
        .padding(14)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.red)
      .disabled(viewModel.isAuthenticating)
    }
  }

  private func accountCard<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .background(Color(.secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(.primary.opacity(0.06))
      }
  }

  private func settingsSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.leading, 4)

      content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
  }

  private func settingsRow<Content: View>(
    icon: String,
    tint: Color,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .foregroundStyle(.white)
        .font(.caption.weight(.bold))
        .frame(width: 30, height: 30)
        .background(tint, in: RoundedRectangle(cornerRadius: 8))
      content()
      Spacer(minLength: 0)
    }
    .padding(14)
  }

  private func avatar(systemImage: String, tint: Color) -> some View {
    Image(systemName: systemImage)
      .font(.title2.weight(.semibold))
      .foregroundStyle(tint)
      .frame(width: 52, height: 52)
      .background(.quaternary, in: Circle())
  }

  @ViewBuilder
  private func profileAvatar(for viewer: AuthenticatedViewer) -> some View {
    if let imageURL = viewer.imageURL {
      AsyncImage(
        url: imageURL,
        transaction: Transaction(animation: .easeInOut(duration: 0.2))
      ) { phase in
        switch phase {
        case let .success(image):
          image
            .resizable()
            .scaledToFill()
        case .empty, .failure:
          initialsAvatar(for: viewer)
        @unknown default:
          initialsAvatar(for: viewer)
        }
      }
      .frame(width: 52, height: 52)
      .clipShape(Circle())
      .overlay {
        Circle()
          .strokeBorder(.primary.opacity(0.08))
      }
      .accessibilityLabel("Profile photo")
    } else {
      initialsAvatar(for: viewer)
    }
  }

  private func initialsAvatar(for viewer: AuthenticatedViewer) -> some View {
    Text(initials(for: viewer))
      .font(.headline)
      .foregroundStyle(.white)
      .frame(width: 52, height: 52)
      .background(Color.accentColor, in: Circle())
      .accessibilityLabel("Profile initials")
  }

  private func initials(for viewer: AuthenticatedViewer) -> String {
    let source = viewer.name ?? viewer.email ?? "User"
    let words = source.split(whereSeparator: { $0 == " " || $0 == "@" })
    return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
  }
}
