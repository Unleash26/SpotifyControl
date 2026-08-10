import Foundation
import XCTest
@testable import SpotifyControl

final class SpotifyScriptParserTests: XCTestCase {
    func testParsesPlayingSnapshot() throws {
        let snapshot = try SpotifyScriptParser.snapshot(from: [
            "playing",
            "春を告げる",
            "yama",
            "the meaning of life",
            "https://example.com/artwork.jpg",
            "64"
        ])

        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertEqual(snapshot.title, "春を告げる")
        XCTAssertEqual(snapshot.artist, "yama")
        XCTAssertEqual(snapshot.album, "the meaning of life")
        XCTAssertEqual(snapshot.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
        XCTAssertEqual(snapshot.volume, 64)
    }

    func testRejectsIncompleteResponse() {
        XCTAssertThrowsError(try SpotifyScriptParser.snapshot(from: ["playing"])) { error in
            XCTAssertEqual(error as? SpotifyBridgeError, .invalidResponse)
        }
    }

    func testClampsOutOfRangeVolume() throws {
        let high = try SpotifyScriptParser.snapshot(from: ["paused", "", "", "", "", "180"])
        let low = try SpotifyScriptParser.snapshot(from: ["paused", "", "", "", "", "-10"])

        XCTAssertEqual(high.volume, 100)
        XCTAssertEqual(low.volume, 0)
        XCTAssertEqual(high.title, "曲情報なし")
        XCTAssertEqual(high.artist, "一時停止中")
    }

    func testMapsAutomationPermissionError() {
        let error: NSDictionary = [
            NSAppleScript.errorNumber: -1743,
            NSAppleScript.errorMessage: "Not authorized to send Apple events."
        ]

        XCTAssertEqual(
            SpotifyScriptParser.bridgeError(from: error),
            .automationPermissionDenied
        )
    }

    func testMapsAppleEventTimeout() {
        let error: NSDictionary = [
            NSAppleScript.errorNumber: -1712,
            NSAppleScript.errorMessage: "AppleEvent timed out."
        ]

        XCTAssertEqual(
            SpotifyScriptParser.bridgeError(from: error),
            .appleScriptTimedOut
        )
    }
}
