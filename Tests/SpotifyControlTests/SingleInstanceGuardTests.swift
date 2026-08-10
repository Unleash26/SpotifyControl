import XCTest
@testable import SpotifyControl

final class SingleInstanceGuardTests: XCTestCase {
    func testOnlyOneGuardCanOwnAnIdentifier() {
        let identifier = "SpotifyControlTests.\(UUID().uuidString)"
        let first = SingleInstanceGuard(identifier: identifier)
        let second = SingleInstanceGuard(identifier: identifier)

        XCTAssertTrue(first.acquire())
        XCTAssertFalse(second.acquire())

        first.release()
        XCTAssertTrue(second.acquire())
        second.release()
    }
}
