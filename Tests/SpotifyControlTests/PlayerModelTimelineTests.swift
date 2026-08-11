import Foundation
import XCTest
@testable import SpotifyControl

final class PlayerModelTimelineTests: XCTestCase {
    @MainActor
    func testPlayingPositionAdvancesFromSnapshotTimeAndClampsAtDuration() async {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let model = PlayerModel(
            fetchSpotifySnapshot: {
                Self.snapshot(state: .playing, position: 10, duration: 20)
            },
            dateProvider: { receivedAt }
        )

        await model.refresh()

        XCTAssertEqual(model.displayedPosition(at: receivedAt), 10)
        XCTAssertEqual(model.displayedPosition(at: receivedAt.addingTimeInterval(4.5)), 14.5)
        XCTAssertEqual(model.displayedPosition(at: receivedAt.addingTimeInterval(30)), 20)
        model.stop()
    }

    @MainActor
    func testPausedPositionDoesNotAdvance() async {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 2_000)
        let model = PlayerModel(
            fetchSpotifySnapshot: {
                Self.snapshot(state: .paused, position: 42, duration: 180)
            },
            dateProvider: { receivedAt }
        )

        await model.refresh()

        XCTAssertEqual(model.displayedPosition(at: receivedAt.addingTimeInterval(60)), 42)
        model.stop()
    }

    @MainActor
    func testDragPreviewSurvivesRefreshAndCommitsOneClampedSeek() async {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 3_000)
        var fetchedSnapshot = Self.snapshot(
            state: .playing,
            position: 15,
            duration: 120
        )
        var writes: [Double] = []
        var fetchCount = 0
        let model = PlayerModel(
            seekRefreshDelay: .zero,
            fetchSpotifySnapshot: {
                fetchCount += 1
                return fetchedSnapshot
            },
            setSpotifyPosition: { seconds in
                writes.append(seconds)
                fetchedSnapshot.positionSeconds = seconds
            },
            dateProvider: { receivedAt }
        )

        await model.refresh()
        model.setPlaybackPosition(80, isEditing: true)
        model.setPlaybackPosition(90, isEditing: true)

        XCTAssertEqual(writes, [])
        XCTAssertEqual(model.displayedPosition(at: receivedAt.addingTimeInterval(50)), 90)

        fetchedSnapshot.positionSeconds = 25
        await model.refresh()

        XCTAssertEqual(model.snapshot.positionSeconds, 25)
        XCTAssertEqual(model.displayedPosition(at: receivedAt.addingTimeInterval(50)), 90)

        model.setPlaybackPosition(999, isEditing: false)

        let didCommitAndRefresh = await waitUntil {
            writes == [120] && fetchCount >= 3 && model.snapshot.positionSeconds == 120
        }
        XCTAssertTrue(didCommitAndRefresh)
        XCTAssertEqual(model.displayedPosition(at: receivedAt), 120)
        model.stop()
    }

    @MainActor
    func testSeekClampsNegativeValueToZero() async {
        var writes: [Double] = []
        let model = PlayerModel(
            seekRefreshDelay: .zero,
            fetchSpotifySnapshot: {
                Self.snapshot(state: .paused, position: 30, duration: 100)
            },
            setSpotifyPosition: { writes.append($0) }
        )

        await model.refresh()
        model.setPlaybackPosition(-50, isEditing: false)

        let didCommit = await waitUntil { writes == [0] }
        XCTAssertTrue(didCommit)
        model.stop()
    }

    @MainActor
    func testRefreshFailureDuringDragCancelsPreviewWithoutSeekingToZero() async {
        var shouldFail = false
        var writes: [Double] = []
        let model = PlayerModel(
            seekRefreshDelay: .zero,
            fetchSpotifySnapshot: {
                if shouldFail {
                    throw SpotifyBridgeError.appleScriptFailed("Spotify unavailable")
                }
                return Self.snapshot(state: .playing, position: 30, duration: 120)
            },
            setSpotifyPosition: { writes.append($0) }
        )

        await model.refresh()
        model.setPlaybackPosition(90, isEditing: true)
        shouldFail = true
        await model.refresh()

        XCTAssertEqual(model.snapshot.state, .connectionError)
        XCTAssertEqual(model.displayedPosition(), 0)

        model.setPlaybackPosition(90, isEditing: false)
        try? await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(writes, [])
        model.stop()
    }

    @MainActor
    func testZeroDurationRefreshDuringDragCancelsPreviewWithoutSeeking() async {
        var fetchedSnapshot = Self.snapshot(state: .playing, position: 30, duration: 120)
        var writes: [Double] = []
        let model = PlayerModel(
            seekRefreshDelay: .zero,
            fetchSpotifySnapshot: { fetchedSnapshot },
            setSpotifyPosition: { writes.append($0) }
        )

        await model.refresh()
        model.setPlaybackPosition(90, isEditing: true)
        fetchedSnapshot = Self.snapshot(state: .stopped, position: 0, duration: 0)
        await model.refresh()

        XCTAssertEqual(model.snapshot.state, .stopped)
        XCTAssertEqual(model.displayedPosition(), 0)

        model.setPlaybackPosition(90, isEditing: false)
        try? await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(writes, [])
        model.stop()
    }

    private static func snapshot(
        state: PlaybackState,
        position: Double,
        duration: Double
    ) -> SpotifySnapshot {
        SpotifySnapshot(
            state: state,
            title: "Track",
            artist: "Artist",
            album: "Album",
            artworkURL: nil,
            volume: 50,
            positionSeconds: position,
            durationSeconds: duration,
            message: nil
        )
    }

    @MainActor
    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<timeoutIterations {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
