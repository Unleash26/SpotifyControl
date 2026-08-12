import AppKit
import XCTest
@testable import SpotifyControl

final class OverlayFrameRestorationTests: XCTestCase {
    func testParsesSavedWindowFrameAndRejectsInvalidFrames() {
        XCTAssertEqual(
            OverlayFrameRestoration.savedWindowFrame(
                from: "1147 208 471 206 0 0 1920 1050 "
            ),
            NSRect(x: 1_147, y: 208, width: 471, height: 206)
        )
        XCTAssertNil(OverlayFrameRestoration.savedWindowFrame(from: "not a frame"))
        XCTAssertNil(OverlayFrameRestoration.savedWindowFrame(from: "0 0 -1 150"))
    }

    func testLegacyShadowGutterMigrationPreservesVisibleCardOrigin() {
        let scale: CGFloat = 1.154_411_764_705_882
        let currentSize = OverlaySizing.windowSize(for: scale)
        let migrated = OverlayFrameRestoration.originPreservingVisibleCard(
            // AppKit keeps the saved top edge for this borderless panel and can
            // therefore report a different restored Y. Migration must use the
            // persisted legacy origin rather than this adjusted value.
            restoredOrigin: NSPoint(x: 1_147, y: 240),
            savedWindowFrame: NSRect(x: 1_147, y: 208, width: 471, height: 206),
            currentWindowSize: currentSize
        )

        XCTAssertEqual(migrated.x, 1_163.161_764_705_882, accuracy: 0.000_001)
        XCTAssertEqual(migrated.y, 224.161_764_705_882, accuracy: 0.000_001)
    }

    func testCurrentEdgeToEdgeFrameDoesNotMoveAgain() {
        let origin = NSPoint(x: 1_163, y: 224)
        let currentSize = OverlaySizing.windowSize(for: 1.154_411_764_705_882)

        XCTAssertEqual(
            OverlayFrameRestoration.originPreservingVisibleCard(
                restoredOrigin: origin,
                savedWindowFrame: NSRect(origin: origin, size: currentSize),
                currentWindowSize: currentSize
            ),
            origin
        )
    }

    func testClampsExpandedCardInsideRightEdge() {
        let size = OverlaySizing.windowSize(for: 1)
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: 4_754, y: 1_208),
            size: size,
            visibleFrame: NSRect(x: 0, y: 0, width: 5_120, height: 1_410)
        )

        XCTAssertEqual(frame, NSRect(x: 4_740, y: 1_208, width: 380, height: 150))
    }

    func testClampsOriginAtEveryVisibleEdge() {
        let size = OverlaySizing.windowSize(for: 1)
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: -80, y: 1_380),
            size: size,
            visibleFrame: NSRect(x: 0, y: 24, width: 1_920, height: 1_056)
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 930, width: 380, height: 150))
    }

    func testPreservesValidOriginOnSecondaryDisplay() {
        let size = OverlaySizing.windowSize(for: 1)
        let frame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: NSPoint(x: 5_380, y: 180),
            size: size,
            visibleFrame: NSRect(x: 5_120, y: 0, width: 2_560, height: 1_410)
        )

        XCTAssertEqual(frame, NSRect(x: 5_380, y: 180, width: 380, height: 150))
    }
}
