import Foundation

enum AppConfiguration {
  static var convexURL: URL {
    guard
      let rawValue = Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String,
      let url = URL(string: rawValue)
    else {
      preconditionFailure("CONVEX_URL must be a valid URL in Info.plist")
    }

    return url
  }

  static var authSiteURL: URL {
    guard
      let rawValue = Bundle.main.object(forInfoDictionaryKey: "AUTH_SITE_URL") as? String,
      let url = URL(string: rawValue)
    else {
      preconditionFailure("AUTH_SITE_URL must be a valid URL in Info.plist")
    }

    return url
  }

  static var isGoogleSignInConfigured: Bool {
    Bundle.main.object(forInfoDictionaryKey: "GOOGLE_AUTH_ENABLED") as? String == "YES"
  }
}
