import Combine
import XCTest
@testable import Starter

final class BootstrapEventDecodingTests: XCTestCase {
  private enum TestFailure: Error {
    case expected
  }

  private final class BackgroundSubject: @unchecked Sendable {
    let value = PassthroughSubject<[BootstrapEvent], TestFailure>()
  }

  private var cancellable: AnyCancellable?

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
    XCTAssertEqual(event.authenticated, true)
    XCTAssertEqual(event.authenticationLabel, "Authenticated")
  }

  @MainActor
  func testSubscriptionFailureReturnsToMainActor() async {
    let completed = expectation(description: "Publisher completes")
    let subject = BackgroundSubject()

    cancellable = LiveStarterConvexAPI
      .adaptSubscription(subject.value.eraseToAnyPublisher())
      .sink(
        receiveCompletion: { result in
          XCTAssertTrue(Thread.isMainThread)
          guard case .failure = result else {
            return XCTFail("Expected the background failure")
          }
          completed.fulfill()
        },
        receiveValue: { _ in
          XCTFail("Expected no value")
        }
      )

    DispatchQueue.global().async {
      XCTAssertFalse(Thread.isMainThread)
      subject.value.send(completion: .failure(.expected))
    }

    await fulfillment(of: [completed], timeout: 2)
  }
}
