import XCTest

final class StarterUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testNativePingRoundTrip() {
    let app = XCUIApplication()
    app.launchEnvironment["STARTER_AUTH_MODE"] = "demo"
    app.launch()

    XCTAssertTrue(
      app.staticTexts["Connected to Convex"].waitForExistence(timeout: 20),
      "The app never connected to local Convex."
    )

    XCTAssertFalse(app.tabBars.buttons["Activity"].exists)
    app.tabBars.buttons["Settings"].tap()

    let signInButton = app.buttons["Sign in demo user"]
    if signInButton.waitForExistence(timeout: 3) {
      signInButton.tap()
    }

    XCTAssertTrue(
      app.staticTexts["Signed in securely"].waitForExistence(timeout: 20),
      "The native Better Auth session did not render in the Settings profile card."
    )
    XCTAssertTrue(
      app.staticTexts["native-starter-demo@example.test"].waitForExistence(timeout: 5),
      "The authenticated Better Auth user was not rendered from Convex."
    )
    let noSubscription = app.staticTexts["No active subscription"]
    let activeSubscription = app.staticTexts["Starter plan"]
    let billingStateRendered = noSubscription.waitForExistence(timeout: 10)
      || activeSubscription.exists
    XCTAssertTrue(billingStateRendered, "The native Better Auth Stripe state was not rendered.")
    if noSubscription.exists {
      XCTAssertTrue(
        app.buttons["Start Starter plan"].exists,
        "The native Stripe Checkout entry point was not rendered."
      )
    }

    let profileAttachment = XCTAttachment(screenshot: app.screenshot())
    profileAttachment.name = "Starter iOS Settings profile"
    profileAttachment.lifetime = .keepAlways
    add(profileAttachment)

    app.tabBars.buttons["Home"].tap()
    app.buttons["Send native ping"].tap()

    XCTAssertTrue(
      app.staticTexts["iOS"].firstMatch.waitForExistence(timeout: 20),
      "The iOS mutation did not render through the reactive subscription."
    )
    XCTAssertTrue(
      app.staticTexts["Authenticated"].firstMatch.waitForExistence(timeout: 5),
      "The ping did not prove that Convex received the authenticated session."
    )

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Starter iOS Better Auth and Convex round trip"
    attachment.lifetime = .keepAlways
    add(attachment)

    app.tabBars.buttons["Settings"].tap()
    app.buttons["Sign out"].tap()

    let signOutAlert = app.alerts["Sign out?"]
    XCTAssertTrue(
      signOutAlert.waitForExistence(timeout: 5),
      "Sign out did not use the centered native alert."
    )
    XCTAssertTrue(signOutAlert.buttons["Cancel"].exists)
    XCTAssertTrue(signOutAlert.buttons["Sign out"].exists)

    let alertAttachment = XCTAttachment(screenshot: app.screenshot())
    alertAttachment.name = "Starter iOS centered sign-out alert"
    alertAttachment.lifetime = .keepAlways
    add(alertAttachment)

    signOutAlert.buttons["Sign out"].tap()
    XCTAssertTrue(
      app.buttons["Sign in demo user"].waitForExistence(timeout: 10),
      "The signed-out account state did not return after confirmation."
    )

    app.tabBars.buttons["Home"].tap()
    app.buttons["Send native ping"].tap()
    XCTAssertTrue(
      app.staticTexts["Not authenticated"].firstMatch.waitForExistence(timeout: 20),
      "The signed-out ping did not report that Convex received no authenticated session."
    )

    app.terminate()

    let nativeApp = XCUIApplication()
    nativeApp.launch()
    nativeApp.tabBars.buttons["Settings"].tap()

    let appleButton = nativeApp.buttons["Sign in with Apple"]
    let googleButton = nativeApp.buttons["Sign in with Google"]
    XCTAssertTrue(appleButton.waitForExistence(timeout: 10))
    XCTAssertTrue(googleButton.waitForExistence(timeout: 10))
    XCTAssertEqual(appleButton.frame.width, googleButton.frame.width, accuracy: 1)
    XCTAssertEqual(appleButton.frame.height, googleButton.frame.height, accuracy: 1)
    XCTAssertEqual(appleButton.frame.height, 52, accuracy: 1)

    let authAttachment = XCTAttachment(screenshot: nativeApp.screenshot())
    authAttachment.name = "Starter iOS native sign-in controls"
    authAttachment.lifetime = .keepAlways
    add(authAttachment)
  }
}
