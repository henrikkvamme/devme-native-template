import XCTest
@testable import Starter

final class BootstrapEventDecodingTests: XCTestCase {
  func testDecodesDeployedWireFixture() throws {
    let fixtureURL = try XCTUnwrap(
      Bundle(for: Self.self).url(
        forResource: "bootstrap-event",
        withExtension: "json"
      )
    )

    let event = try JSONDecoder().decode(
      BootstrapEvent.self,
      from: Data(contentsOf: fixtureURL)
    )

    XCTAssertEqual(event.client, "test")
    XCTAssertEqual(event.message, "Backend is connected")
  }
}
