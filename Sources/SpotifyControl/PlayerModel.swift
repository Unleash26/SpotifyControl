import AppKit
import Foundation

@MainActor
final class PlayerModel: ObservableObject {
    @Published private(set) var snapshot = SpotifySnapshot.notRunning
    @Published var volume: Double = 50

    private let bridge = SpotifyBridge()
    private var refreshTask: Task<Void, Never>?
    private var volumeTask: Task<Void, Never>?
    private var isEditingVolume = false
    private var refreshGeneration = 0
    private var volumeWriteGeneration = 0
    private var pendingVolumeWrite: Int?

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
        refreshTask = nil
        volumeTask = nil
    }

    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration

        do {
            let newSnapshot = try await bridge.snapshot()
            guard generation == refreshGeneration else { return }
            snapshot = newSnapshot
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
        let generation = volumeWriteGeneration
        let targetVolume = Int(volume.rounded())
        pendingVolumeWrite = targetVolume
        queueVolumeUpdate(
            targetVolume: targetVolume,
            generation: generation,
            delayNanoseconds: isEditing ? 140_000_000 : 0
        )
    }

    private func queueVolumeUpdate(
        targetVolume: Int,
        generation: Int,
        delayNanoseconds: UInt64
    ) {
        volumeTask?.cancel()

        volumeTask = Task { [weak self] in
            guard let self else { return }
            if delayNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            do {
                try await bridge.setVolume(targetVolume)
                if generation == volumeWriteGeneration {
                    pendingVolumeWrite = nil
                }
            } catch {
                if generation == volumeWriteGeneration {
                    pendingVolumeWrite = nil
                    present(error)
                }
            }
        }
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
            message: error.localizedDescription
        )
    }
}
