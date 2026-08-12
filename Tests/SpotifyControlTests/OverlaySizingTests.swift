import XCTest
@testable import SpotifyControl

final class OverlaySizingTests: XCTestCase {
    func testScaleBoundsAllowACompactUtilitySize() {
        XCTAssertEqual(OverlaySizing.minimumScale, 0.55, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.windowSize(for: .zero).width, 224.4, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.windowSize(for: .zero).height, 97.9, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.contentSize(for: .zero).width, 209, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.contentSize(for: .zero).height, 82.5, accuracy: 0.000_001)

        XCTAssertEqual(OverlaySizing.windowSize(for: 1).width, 408, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.windowSize(for: 1).height, 178, accuracy: 0.000_001)

        XCTAssertEqual(OverlaySizing.windowSize(for: 99).width, 550.8, accuracy: 0.000_001)
        XCTAssertEqual(OverlaySizing.windowSize(for: 99).height, 240.3, accuracy: 0.000_001)
    }

    func testScalePersistenceRoundTripInvalidFallbackAndLegacyMigration() throws {
        let suiteName = "SpotifyControlTests.OverlaySizing.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(OverlaySizing.load(from: defaults), 1, accuracy: 0.000_001)

        OverlaySizing.save(0.643, to: defaults)
        XCTAssertEqual(OverlaySizing.load(from: defaults), 0.643, accuracy: 0.000_001)

        defaults.set("unsupported", forKey: OverlaySizing.defaultsKey)
        XCTAssertEqual(OverlaySizing.load(from: defaults), 1, accuracy: 0.000_001)

        defaults.removeObject(forKey: OverlaySizing.defaultsKey)
        defaults.set("compact", forKey: "OverlaySizePreset")
        XCTAssertEqual(OverlaySizing.load(from: defaults), 0.9, accuracy: 0.000_001)

        defaults.set("large", forKey: "OverlaySizePreset")
        XCTAssertEqual(OverlaySizing.load(from: defaults), 1.2, accuracy: 0.000_001)
    }

    func testBottomRightDragProjectsPointerMotionAndPreservesBounds() {
        let initialFrame = NSRect(x: 300, y: 400, width: 408, height: 178)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_200, height: 900)

        let smaller = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: NSPoint(x: 708, y: 400),
            currentMouseLocation: NSPoint(x: 504, y: 489),
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(smaller, OverlaySizing.minimumScale, accuracy: 0.000_001)

        let larger = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: NSPoint(x: 708, y: 400),
            currentMouseLocation: NSPoint(x: 912, y: 311),
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(larger, 1.35, accuracy: 0.000_001)
    }

    func testBottomRightDragDoesNotJumpAcrossAxisDominanceBoundary() {
        let initialFrame = NSRect(x: 300, y: 400, width: 408, height: 178)
        let visibleFrame = NSRect(x: 0, y: 0, width: 2_000, height: 1_500)
        let start = NSPoint(x: initialFrame.maxX, y: initialFrame.minY)
        let targetScaleDelta: CGFloat = 0.2
        let perpendicularNoise: CGFloat = 0.08
        let baseDeltaX = OverlayLayout.windowWidth * targetScaleDelta
        let baseDeltaY = -OverlayLayout.windowHeight * targetScaleDelta
        let noiseX = OverlayLayout.windowHeight * perpendicularNoise
        let noiseY = OverlayLayout.windowWidth * perpendicularNoise

        let widthDominant = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: start,
            currentMouseLocation: NSPoint(
                x: start.x + baseDeltaX + noiseX,
                y: start.y + baseDeltaY + noiseY
            ),
            visibleFrame: visibleFrame
        )
        let heightDominant = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: start,
            currentMouseLocation: NSPoint(
                x: start.x + baseDeltaX - noiseX,
                y: start.y + baseDeltaY - noiseY
            ),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(widthDominant, 1.2, accuracy: 0.000_001)
        XCTAssertEqual(heightDominant, 1.2, accuracy: 0.000_001)
        XCTAssertEqual(widthDominant, heightDominant, accuracy: 0.000_001)
    }

    func testBottomRightDragStopsAtVisibleRightAndBottomEdges() {
        let initialFrame = NSRect(x: 700, y: 250, width: 408, height: 178)
        let visibleFrame = NSRect(x: 100, y: 100, width: 1_100, height: 700)

        let scale = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: NSPoint(x: 1_108, y: 250),
            currentMouseLocation: NSPoint(x: 1_500, y: 0),
            visibleFrame: visibleFrame
        )
        let size = OverlaySizing.windowSize(for: scale)

        XCTAssertLessThanOrEqual(initialFrame.minX + size.width, visibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(initialFrame.maxY - size.height, visibleFrame.minY)
    }
}
