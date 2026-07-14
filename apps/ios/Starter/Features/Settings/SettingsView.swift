import SwiftUI

struct SettingsView: View {
  @Environment(\.openURL) private var openURL
  @ObservedObject var viewModel: HomeViewModel
  @State private var isConfirmingSignOut = false

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
    .confirmationDialog(
      "Sign out of this device?",
      isPresented: $isConfirmingSignOut,
      titleVisibility: .visible
    ) {
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
        VStack(alignment: .leading, spacing: 20) {
          HStack(spacing: 16) {
            avatar(systemImage: "person.fill", tint: .secondary)
            VStack(alignment: .leading, spacing: 4) {
              Text("Your account")
                .font(.title3.bold())
              Text("Sign in to keep your data and subscription connected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }

          Button {
            Task { await viewModel.signIn() }
          } label: {
            Label("Sign in demo user", systemImage: "person.badge.key.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(viewModel.isAuthenticating)
        }
      }
    case let .signedIn(viewer):
      signedInProfileCard(viewer)
    case let .failed(message):
      accountCard {
        VStack(alignment: .leading, spacing: 18) {
          HStack(spacing: 16) {
            avatar(systemImage: "exclamationmark", tint: .orange)
            VStack(alignment: .leading, spacing: 4) {
              Text("Could not load your account")
                .font(.headline)
              Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            }
          }

          Button("Try again") {
            Task { await viewModel.signIn() }
          }
          .buttonStyle(.bordered)
          .disabled(viewModel.isAuthenticating)
        }
      }
    }
  }

  private func signedInProfileCard(_ viewer: AuthenticatedViewer) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        LinearGradient(
          colors: [Color.accentColor.opacity(0.92), Color.indigo.opacity(0.82)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        Circle()
          .fill(.white.opacity(0.12))
          .frame(width: 150, height: 150)
          .offset(x: 220, y: 68)
      }
      .frame(height: 104)
      .clipped()
      .overlay(alignment: .bottomLeading) {
        avatar(
          text: initials(for: viewer),
          foreground: Color.accentColor,
          background: .white
        )
        .offset(y: 34)
        .padding(.leading, 22)
      }

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(viewer.name ?? "Authenticated user")
            .font(.title2.bold())
            .lineLimit(1)

          Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Authenticated account")
        }

        if let email = viewer.email {
          Text(email)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }

        Label("Signed in securely", systemImage: "lock.shield.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.top, 4)
      }
      .padding(.horizontal, 22)
      .padding(.top, 48)
      .padding(.bottom, 22)
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .strokeBorder(.primary.opacity(0.06))
    }
    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    .accessibilityElement(children: .contain)
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
      .padding(22)
      .background(Color(.secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
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
      .frame(width: 58, height: 58)
      .background(.quaternary, in: Circle())
  }

  private func avatar(text: String, foreground: Color, background: Color) -> some View {
    Text(text)
      .font(.title2.bold())
      .foregroundStyle(foreground)
      .frame(width: 68, height: 68)
      .background(background, in: Circle())
      .overlay {
        Circle().strokeBorder(.white.opacity(0.7), lineWidth: 3)
      }
      .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
  }

  private func initials(for viewer: AuthenticatedViewer) -> String {
    let source = viewer.name ?? viewer.email ?? "User"
    let words = source.split(whereSeparator: { $0 == " " || $0 == "@" })
    return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
  }
}
