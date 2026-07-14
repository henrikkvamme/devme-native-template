import XCTest

final class StarterUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testNativePingRoundTrip() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(
      app.staticTexts["Connected to Convex"].waitForExistence(timeout: 20),
      "The app never connected to local Convex."
    )

    let signInButton = app.buttons["Sign in demo user"]
    if signInButton.waitForExistence(timeout: 3) {
      signInButton.tap()
    }

    XCTAssertTrue(
      app.staticTexts["Authenticated Convex identity verified"].waitForExistence(timeout: 20),
      "The native Better Auth session did not become an authenticated Convex identity."
    )
    XCTAssertTrue(
      app.staticTexts["native-starter-demo@example.test"].waitForExistence(timeout: 5),
      "The authenticated Better Auth user was not rendered from Convex."
    )
    let noSubscription = app.staticTexts["No active subscription"]
    let activeSubscription = app.staticTexts["Starter plan active"]
    let billingStateRendered = noSubscription.waitForExistence(timeout: 10)
      || activeSubscription.exists
    XCTAssertTrue(billingStateRendered, "The native Better Auth Stripe state was not rendered.")
    if noSubscription.exists {
      XCTAssertTrue(
        app.buttons["Start Starter plan"].exists,
        "The native Stripe Checkout entry point was not rendered."
      )
    }

    app.buttons["Send native ping"].tap()

    XCTAssertTrue(
      app.staticTexts["iOS"].firstMatch.waitForExistence(timeout: 20),
      "The iOS mutation did not render through the reactive subscription."
    )

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Starter iOS Better Auth and Convex round trip"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
