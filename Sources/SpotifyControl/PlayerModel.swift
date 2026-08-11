import AppKit
import Foundation

@MainActor
final class PlayerModel: ObservableObject {
    @Published private(set) var snapshot = SpotifySnapshot.notRunning
    @Published var volume: Double = 50
    @Published private var playbackPositionPreview: Double?

    private let bridge: SpotifyBridge
    private let volumeWriteInterval: Duration
    private let seekRefreshDelay: Duration
    private let fetchSpotifySnapshot: @MainActor () async throws -> SpotifySnapshot
    private let setSpotifyPosition: @MainActor (Double) async throws -> Void
    private let setSpotifyVolume: @MainActor (Int) async throws -> Void
    private let dateProvider: @MainActor () -> Date
    private let volumeClock = ContinuousClock()
    private var refreshTask: Task<Void, Never>?
    private var volumeTask: Task<Void, Never>?
    private var seekTask: Task<Void, Never>?
    private var isEditingVolume = false
    private var snapshotReceivedAt = Date()
    private var refreshGeneration = 0
    private var seekGeneration = 0
    private var volumeWriteGeneration = 0
    private var volumeWorkerGeneration = 0
    private var pendingVolumeWrite: Int?
    private var lastVolumeWriteAt: ContinuousClock.Instant?

    init(
        volumeWriteInterval: Duration = .milliseconds(50),
        seekRefreshDelay: Duration = .milliseconds(250),
        fetchSpotifySnapshot: (@MainActor () async throws -> SpotifySnapshot)? = nil,
        setSpotifyPosition: (@MainActor (Double) async throws -> Void)? = nil,
        dateProvider: (@MainActor () -> Date)? = nil,
        setSpotifyVolume: (@MainActor (Int) async throws -> Void)? = nil
    ) {
        let bridge = SpotifyBridge()
        self.bridge = bridge
        self.volumeWriteInterval = volumeWriteInterval
        self.seekRefreshDelay = seekRefreshDelay
        self.fetchSpotifySnapshot = fetchSpotifySnapshot ?? {
            try await bridge.snapshot()
        }
        self.setSpotifyPosition = setSpotifyPosition ?? { seconds in
            try await bridge.setPlayerPosition(seconds)
        }
        self.dateProvider = dateProvider ?? Date.init
        self.setSpotifyVolume = setSpotifyVolume ?? { volume in
            try await bridge.setVolume(volume)
        }
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                do {
                    try await Task.sleep(for: .seconds(1.5))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        volumeTask?.cancel()
        seekTask?.cancel()
        volumeWorkerGeneration += 1
        seekGeneration += 1
        refreshTask = nil
        volumeTask = nil
        seekTask = nil
        pendingVolumeWrite = nil
        lastVolumeWriteAt = nil
        playbackPositionPreview = nil
    }

    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration

        do {
            let newSnapshot = try await fetchSpotifySnapshot()
            guard generation == refreshGeneration else { return }
            snapshot = newSnapshot
            snapshotReceivedAt = dateProvider()
            if !newSnapshot.durationSeconds.isFinite || newSnapshot.durationSeconds <= 0 {
                cancelPlaybackPositionEditing()
            }
            if !isEditingVolume && pendingVolumeWrite == nil {
                volume = Double(newSnapshot.volume)
            }
        } catch {
            guard generation == refreshGeneration else { return }
            present(error)
        }
    }

    func playPause() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await bridge.playPause()
                await refreshSoon()
            } catch {
                present(error)
            }
        }
    }

    func nextTrack() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await bridge.nextTrack()
                await refreshSoon()
            } catch {
                present(error)
            }
        }
    }

    func previousTrack() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await bridge.previousTrack()
                await refreshSoon()
            } catch {
                present(error)
            }
        }
    }

    func openSpotify() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await bridge.openSpotify()
                await refreshSoon()
            } catch {
                present(error)
            }
        }
    }

    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setVolume(_ newVolume: Double, isEditing: Bool) {
        volume = newVolume
        isEditingVolume = isEditing
        volumeWriteGeneration += 1
        let targetVolume = Int(volume.rounded())
        pendingVolumeWrite = targetVolume
        scheduleVolumeUpdate(forceImmediate: !isEditing)
    }

    func displayedPosition(at date: Date = Date()) -> Double {
        if let playbackPositionPreview {
            return playbackPositionPreview
        }

        let elapsed: Double
        if snapshot.state.isPlaying {
            elapsed = max(0, date.timeIntervalSince(snapshotReceivedAt))
        } else {
            elapsed = 0
        }

        return clampedPlaybackPosition(snapshot.positionSeconds + elapsed)
    }

    func setPlaybackPosition(_ seconds: Double, isEditing: Bool) {
        guard snapshot.durationSeconds.isFinite, snapshot.durationSeconds > 0 else {
            cancelPlaybackPositionEditing()
            return
        }

        let targetPosition = clampedPlaybackPosition(seconds)
        playbackPositionPreview = targetPosition

        if isEditing {
            seekTask?.cancel()
            seekTask = nil
            seekGeneration += 1
            return
        }

        seekTask?.cancel()
        seekGeneration += 1
        let generation = seekGeneration

        seekTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await setSpotifyPosition(targetPosition)
                guard !Task.isCancelled, generation == seekGeneration else { return }
                await refreshAfterSeek()
                guard !Task.isCancelled, generation == seekGeneration else { return }
                playbackPositionPreview = nil
                seekTask = nil
            } catch {
                guard generation == seekGeneration else { return }
                playbackPositionPreview = nil
                seekTask = nil
                present(error)
            }
        }
    }

    private func scheduleVolumeUpdate(forceImmediate: Bool) {
        if forceImmediate {
            volumeTask?.cancel()
            volumeTask = nil
        } else if volumeTask != nil {
            return
        }

        let delay = volumeWriteDelay(forceImmediate: forceImmediate)
        volumeWorkerGeneration += 1
        let workerGeneration = volumeWorkerGeneration

        volumeTask = Task { [weak self] in
            guard let self else { return }
            if delay != .zero {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await flushPendingVolume(workerGeneration: workerGeneration)
        }
    }

    private func volumeWriteDelay(forceImmediate: Bool) -> Duration {
        guard !forceImmediate, let lastVolumeWriteAt else { return .zero }
        let elapsed = lastVolumeWriteAt.duration(to: volumeClock.now)
        return elapsed < volumeWriteInterval ? volumeWriteInterval - elapsed : .zero
    }

    private func flushPendingVolume(workerGeneration: Int) async {
        guard workerGeneration == volumeWorkerGeneration else { return }
        guard let targetVolume = pendingVolumeWrite else {
            volumeTask = nil
            return
        }

        let generation = volumeWriteGeneration
        lastVolumeWriteAt = volumeClock.now

        do {
            try await setSpotifyVolume(targetVolume)
            if generation == volumeWriteGeneration {
                pendingVolumeWrite = nil
            }
        } catch {
            if generation == volumeWriteGeneration {
                pendingVolumeWrite = nil
                present(error)
            }
        }

        guard workerGeneration == volumeWorkerGeneration else { return }
        volumeTask = nil

        if pendingVolumeWrite != nil {
            scheduleVolumeUpdate(forceImmediate: !isEditingVolume)
        }
    }

    private func clampedPlaybackPosition(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return 0 }
        let duration = snapshot.durationSeconds
        guard duration.isFinite, duration > 0 else { return 0 }
        return min(duration, max(0, seconds))
    }

    private func refreshAfterSeek() async {
        if seekRefreshDelay != .zero {
            do {
                try await Task.sleep(for: seekRefreshDelay)
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }
        await refresh()
    }

    private func cancelPlaybackPositionEditing() {
        seekTask?.cancel()
        seekTask = nil
        seekGeneration += 1
        playbackPositionPreview = nil
    }

    private func refreshSoon() async {
        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return
        }
        await refresh()
    }

    private func present(_ error: Error) {
        cancelPlaybackPositionEditing()
        let bridgeError = error as? SpotifyBridgeError
        let state: PlaybackState
        let title: String
        let detail: String

        if bridgeError == .automationPermissionDenied {
            state = .permissionDenied
            title = "操作許可が必要です"
            detail = "右クリックしてオートメーション設定を開く"
        } else {
            state = .connectionError
            title = "Spotifyに接続できません"
            detail = bridgeError?.recoverySuggestion ?? error.localizedDescription
        }

        snapshot = SpotifySnapshot(
            state: state,
            title: title,
            artist: detail,
            album: "",
            artworkURL: nil,
            volume: Int(volume.rounded()),
            positionSeconds: 0,
            durationSeconds: 0,
            message: error.localizedDescription
        )
    }
}
