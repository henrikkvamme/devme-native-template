import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
  enum ConnectionState: Equatable {
    case connecting
    case connected
    case failed(String)
  }

  enum AuthenticationState: Equatable {
    case loading
    case signedOut
    case signedIn(AuthenticatedViewer)
  }

  enum BillingState: Equatable {
    case unavailable
    case loading
    case free
    case active(BetterAuthSubscription)
    case failed(String)
  }

  @Published private(set) var connectionState: ConnectionState = .connecting
  @Published private(set) var events: [BootstrapEvent] = []
  @Published private(set) var isSendingPing = false
  @Published private(set) var authenticationState: AuthenticationState = .loading
  @Published private(set) var isAuthenticating = false
  @Published private(set) var authenticationErrorMessage: String?
  @Published private(set) var billingState: BillingState = .unavailable
  @Published private(set) var isStartingCheckout = false

  private let backend: StarterBackend
  private var subscription: AnyCancellable?

  init(backend: StarterBackend) {
    self.backend = backend
  }

  var authenticationMode: StarterAuthenticationMode {
    backend.authenticationMode
  }

  func start() async {
    guard subscription == nil else { return }

    subscription = backend
      .bootstrapEvents()
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          guard case let .failure(error) = completion else { return }
          self?.connectionState = .failed(error.localizedDescription)
        },
        receiveValue: { [weak self] events in
          self?.events = events
          self?.connectionState = .connected
        }
      )

    do {
      if let viewer = try await backend.restoreSession() {
        authenticationState = .signedIn(viewer)
        await refreshBilling()
      } else {
        authenticationState = .signedOut
      }
    } catch {
      authenticationState = .signedOut
      authenticationErrorMessage = "Your saved session could not be restored. Please sign in again."
    }
  }

  func sendPing() async {
    guard !isSendingPing else { return }
    isSendingPing = true
    defer { isSendingPing = false }

    do {
      try await backend.ping()
    } catch {
      connectionState = .failed(error.localizedDescription)
    }
  }

  func signIn(with credential: NativeIdentityCredential? = nil) async {
    guard !isAuthenticating else { return }
    isAuthenticating = true
    authenticationErrorMessage = nil
    defer { isAuthenticating = false }

    do {
      authenticationState = .signedIn(try await backend.signIn(with: credential))
      await refreshBilling()
    } catch {
      authenticationState = .signedOut
      authenticationErrorMessage = AuthenticationErrorPresentation.message(
        for: error,
        provider: credential?.provider
      )
    }
  }

  func reportAuthenticationError(
    _ error: Error,
    provider: NativeSocialProvider? = nil
  ) {
    authenticationState = .signedOut
    authenticationErrorMessage = AuthenticationErrorPresentation.message(
      for: error,
      provider: provider
    )
  }

  func returnToSignIn() {
    authenticationState = .signedOut
    authenticationErrorMessage = nil
  }

  func dismissAuthenticationError() {
    authenticationErrorMessage = nil
  }

  func reportAccountDeletionIdentityMismatch() {
    authenticationErrorMessage =
      "Sign in with the same account that you are trying to delete."
  }

  func signOut() async {
    guard !isAuthenticating else { return }
    isAuthenticating = true
    defer { isAuthenticating = false }
    await backend.signOut()
    authenticationState = .signedOut
    authenticationErrorMessage = nil
    billingState = .unavailable
  }

  func deleteAccount() async {
    guard !isAuthenticating else { return }
    isAuthenticating = true
    authenticationErrorMessage = nil
    defer { isAuthenticating = false }

    do {
      try await backend.deleteAccount()
      authenticationState = .signedOut
      billingState = .unavailable
    } catch {
      authenticationErrorMessage = "Your account could not be deleted. Please try again."
    }
  }

  func refreshBilling() async {
    guard case .signedIn = authenticationState else {
      billingState = .unavailable
      return
    }

    billingState = .loading
    do {
      let subscriptions = try await backend.subscriptions()
      if let active = subscriptions.first(where: { $0.status == "active" || $0.status == "trialing" }) {
        billingState = .active(active)
      } else {
        billingState = .free
      }
    } catch {
      billingState = .failed(error.localizedDescription)
    }
  }

  func beginCheckout() async -> URL? {
    guard !isStartingCheckout else { return nil }
    isStartingCheckout = true
    defer { isStartingCheckout = false }

    do {
      return try await backend.subscriptionCheckoutURL()
    } catch {
      billingState = .failed(error.localizedDescription)
      return nil
    }
  }

  func manageSubscription() async -> URL? {
    do {
      return try await backend.billingPortalURL()
    } catch {
      billingState = .failed(error.localizedDescription)
      return nil
    }
  }

  func handleBillingCallback(_ url: URL) async {
    guard url.scheme == "starter", url.host == "billing" else { return }
    guard url.path == "/success" else {
      await refreshBilling()
      return
    }

    for attempt in 0..<5 {
      await refreshBilling()
      if case .active = billingState { return }
      if attempt < 4 {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
  }
}
