import XCTest
@testable import SpotifyControl

@MainActor
final class PlayerModelVolumeTests: XCTestCase {
    func testDraggingSendsFirstValueImmediatelyAndThrottlesToLatestValue() async {
        var writes: [Int] = []
        let model = PlayerModel(volumeWriteInterval: .milliseconds(120)) { volume in
            writes.append(volume)
        }

        model.setVolume(10, isEditing: true)
        let sentFirstValue = await waitUntil { writes == [10] }
        XCTAssertTrue(sentFirstValue)

        model.setVolume(20, isEditing: true)
        model.setVolume(30, isEditing: true)

        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(writes, [10])

        let sentLatestValue = await waitUntil { writes == [10, 30] }
        XCTAssertTrue(sentLatestValue)

        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(writes, [10, 30])
        model.stop()
    }

    func testEndingDragFlushesLatestValueWithoutWaitingForThrottle() async {
        var writes: [Int] = []
        let model = PlayerModel(volumeWriteInterval: .milliseconds(300)) { volume in
            writes.append(volume)
        }

        model.setVolume(10, isEditing: true)
        let sentFirstValue = await waitUntil { writes == [10] }
        XCTAssertTrue(sentFirstValue)

        model.setVolume(20, isEditing: true)
        model.setVolume(30, isEditing: false)

        let flushedFinalValue = await waitUntil { writes == [10, 30] }
        XCTAssertTrue(flushedFinalValue)

        try? await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(writes, [10, 30])
        model.stop()
    }

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
