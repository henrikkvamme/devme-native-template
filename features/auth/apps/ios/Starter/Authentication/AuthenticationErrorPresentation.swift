import Foundation

enum AuthenticationErrorPresentation {
  static func message(
    for error: Error,
    provider: NativeSocialProvider? = nil
  ) -> String {
    if let urlError = error as? URLError,
       [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code)
    {
      return "Check your internet connection and try again."
    }

    if case let BetterAuthNativeError.requestFailed(status, detail) = error,
       status == 404,
       detail.contains("PROVIDER_NOT_FOUND")
    {
      return "\(provider?.displayName ?? "This provider") sign-in is not configured."
    }

    if let provider {
      return "\(provider.displayName) sign-in could not be completed. Please try again."
    }
    return "Sign-in could not be completed. Please try again."
  }
}

extension NativeSocialProvider {
  var displayName: String {
    switch self {
    case .apple: "Apple"
    case .google: "Google"
    }
  }
}
