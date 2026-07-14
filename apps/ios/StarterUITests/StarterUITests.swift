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

    app.buttons["Send native ping"].tap()

    XCTAssertTrue(
      app.staticTexts["iOS"].firstMatch.waitForExistence(timeout: 20),
      "The iOS mutation did not render through the reactive subscription."
    )

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Starter iOS native Convex round trip"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
