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
}
