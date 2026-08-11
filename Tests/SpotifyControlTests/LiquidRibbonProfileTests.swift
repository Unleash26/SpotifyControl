import XCTest
@testable import SpotifyControl

final class LiquidRibbonProfileTests: XCTestCase {
    func testProfileAnchorsAtElapsedEdges() {
        XCTAssertEqual(
            LiquidRibbonProfile.amount(
                at: 0,
                trackWidth: 320,
                activeWidth: 160,
                phase: 1.2,
                isAnimated: true
            ),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            LiquidRibbonProfile.amount(
                at: 160,
                trackWidth: 320,
                activeWidth: 160,
                phase: 1.2,
                isAnimated: true
            ),
            0,
            accuracy: 0.000_001
        )
    }

    func testProfileStaysFiniteAndNormalized() {
        for activeWidth in [0.1, 3, 14, 160, 320] {
            for phase in stride(from: 0.0, through: Double.pi * 2, by: 0.2) {
                for x in stride(from: 0.0, through: activeWidth, by: max(0.1, activeWidth / 80)) {
                    let amount = LiquidRibbonProfile.amount(
                        at: x,
                        trackWidth: 320,
                        activeWidth: activeWidth,
                        phase: phase,
                        isAnimated: true
                    )
                    XCTAssertTrue(amount.isFinite)
                    XCTAssertGreaterThanOrEqual(amount, 0)
                    XCTAssertLessThanOrEqual(amount, 1)
                }
            }
        }
    }

    func testProfileAndClockRepeatAtLoopBoundary() {
        let startDate = Date(timeIntervalSinceReferenceDate: 42)
        let endDate = startDate.addingTimeInterval(LiquidRibbonProfile.loopDuration)
        let startPhase = LiquidRibbonProfile.phase(at: startDate)
        let endPhase = LiquidRibbonProfile.phase(at: endDate)

        XCTAssertEqual(startPhase, endPhase, accuracy: 0.000_001)
        XCTAssertEqual(
            LiquidRibbonProfile.amount(
                at: 72,
                trackWidth: 320,
                activeWidth: 170,
                phase: 0,
                isAnimated: true
            ),
            LiquidRibbonProfile.amount(
                at: 72,
                trackWidth: 320,
                activeWidth: 170,
                phase: .pi * 2,
                isAnimated: true
            ),
            accuracy: 0.000_001
        )
    }

    func testAnimatedProfileMorphsButStaticProfileDoesNot() {
        let animatedStart = LiquidRibbonProfile.amount(
            at: 54,
            trackWidth: 320,
            activeWidth: 170,
            phase: 0,
            isAnimated: true
        )
        let animatedLater = LiquidRibbonProfile.amount(
            at: 54,
            trackWidth: 320,
            activeWidth: 170,
            phase: 1.8,
            isAnimated: true
        )
        XCTAssertNotEqual(animatedStart, animatedLater, accuracy: 0.01)

        let staticStart = LiquidRibbonProfile.amount(
            at: 54,
            trackWidth: 320,
            activeWidth: 170,
            phase: 0,
            isAnimated: false
        )
        let staticLater = LiquidRibbonProfile.amount(
            at: 54,
            trackWidth: 320,
            activeWidth: 170,
            phase: 1.8,
            isAnimated: false
        )
        XCTAssertEqual(staticStart, staticLater, accuracy: 0.000_001)
    }

    func testInvalidAndEmptyGeometryReturnsZero() {
        XCTAssertEqual(
            LiquidRibbonProfile.amount(
                at: 0,
                trackWidth: 0,
                activeWidth: 0,
                phase: 0,
                isAnimated: true
            ),
            0
        )
        XCTAssertEqual(
            LiquidRibbonProfile.amount(
                at: .infinity,
                trackWidth: 320,
                activeWidth: 120,
                phase: 0,
                isAnimated: true
            ),
            0
        )
    }
}
