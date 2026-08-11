import AppKit
import XCTest
@testable import SpotifyControl

final class OverlayFrameRestorationTests: XCTestCase {
    func testClampsExpandedCardInsideRightEdge() {
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: 4_754, y: 1_208),
            size: NSSize(width: 408, height: 178),
            visibleFrame: NSRect(x: 0, y: 0, width: 5_120, height: 1_410)
        )

        XCTAssertEqual(frame, NSRect(x: 4_712, y: 1_208, width: 408, height: 178))
    }

    func testClampsOriginAtEveryVisibleEdge() {
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: -80, y: 1_380),
            size: NSSize(width: 408, height: 178),
            visibleFrame: NSRect(x: 0, y: 24, width: 1_920, height: 1_056)
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 902, width: 408, height: 178))
    }

    func testPreservesValidOriginOnSecondaryDisplay() {
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: 5_380, y: 180),
            size: NSSize(width: 408, height: 178),
            visibleFrame: NSRect(x: 5_120, y: 0, width: 2_560, height: 1_410)
        )

        XCTAssertEqual(frame, NSRect(x: 5_380, y: 180, width: 408, height: 178))
    }
}
