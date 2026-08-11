import AppKit
import Foundation

struct SpotifySnapshot: Equatable, Sendable {
    var state: PlaybackState
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var volume: Int
    var positionSeconds: Double = 0
    var durationSeconds: Double = 0
    var message: String?

    static let unavailable = SpotifySnapshot(
        state: .unavailable,
        title: "Spotifyが見つかりません",
        artist: "Spotifyをインストールしてください",
        album: "",
        artworkURL: nil,
        volume: 50,
        positionSeconds: 0,
        durationSeconds: 0,
        message: nil
    )

    static let notRunning = SpotifySnapshot(
        state: .notRunning,
        title: "Spotifyを起動",
        artist: "再生を始めると曲情報を表示します",
        album: "",
        artworkURL: nil,
        volume: 50,
        positionSeconds: 0,
        durationSeconds: 0,
        message: nil
    )
}

enum PlaybackState: String, Equatable, Sendable {
    case playing
    case paused
    case stopped
    case notRunning
    case unavailable
    case permissionDenied
    case connectionError
    case unknown

    var isPlaying: Bool {
        self == .playing
    }
}

enum SpotifyBridgeError: LocalizedError, Equatable {
    case spotifyUnavailable
    case spotifyLaunchFailed(String)
    case spotifyLaunchTimedOut
    case automationPermissionDenied
    case appleScriptTimedOut
    case invalidResponse
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .spotifyUnavailable:
            return "Spotifyがインストールされていません。"
        case .spotifyLaunchFailed(let message):
            return "Spotifyを起動できませんでした: \(message)"
        case .spotifyLaunchTimedOut:
            return "Spotifyの起動を確認できませんでした。"
        case .automationPermissionDenied:
            return "Spotifyの操作が許可されていません。"
        case .appleScriptTimedOut:
            return "Spotifyから時間内に応答がありませんでした。"
        case .invalidResponse:
            return "Spotifyから想定外の応答を受け取りました。"
        case .appleScriptFailed(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .automationPermissionDenied:
            return "システム設定 > プライバシーとセキュリティ > オートメーションでSpotifyControlを許可してください。"
        default:
            return nil
        }
    }
}

@MainActor
final class SpotifyBridge {
    private static let appleEventTimeoutSeconds = 3
    private let bundleIdentifier = "com.spotify.client"

    func snapshot() async throws -> SpotifySnapshot {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            return SpotifySnapshot.unavailable
        }

        guard isSpotifyRunning else {
            return SpotifySnapshot.notRunning
        }

        let source = """
            tell application id "\(bundleIdentifier)"
                set playbackState to (player state as string)
                set trackName to ""
                set trackArtist to ""
                set trackAlbum to ""
                set trackArtwork to ""
                set currentVolume to (sound volume as string)
                set currentPosition to "0"
                set trackDuration to "0"

                if playbackState is not "stopped" then
                    try
                        set currentTrack to current track
                        set trackName to name of currentTrack
                        set trackArtist to artist of currentTrack
                        set trackAlbum to album of currentTrack
                        set trackArtwork to artwork url of currentTrack
                        set currentPosition to (player position as string)
                        set trackDuration to (duration of currentTrack as string)
                    end try
                end if

                return {playbackState, trackName, trackArtist, trackAlbum, trackArtwork, currentVolume, currentPosition, trackDuration}
            end tell
            """

        let values = try Self.runListScript(source)
        return try SpotifyScriptParser.snapshot(from: values)
    }

    func playPause() async throws {
        if !isSpotifyRunning {
            try await launchSpotify()
            try await waitForSpotifyLaunch()
            try runCommand("""
            tell application id "\(bundleIdentifier)" to play
            """)
            return
        }

        try runCommand("""
        tell application id "\(bundleIdentifier)" to playpause
        """)
    }

    func nextTrack() async throws {
        guard isSpotifyRunning else { return }

        try runCommand("""
        tell application id "\(bundleIdentifier)" to next track
        """)
    }

    func previousTrack() async throws {
        guard isSpotifyRunning else { return }

        try runCommand("""
        tell application id "\(bundleIdentifier)" to previous track
        """)
    }

    func setVolume(_ volume: Int) async throws {
        guard isSpotifyRunning else { return }

        let clampedVolume = min(100, max(0, volume))
        try runCommand("""
        tell application id "\(bundleIdentifier)" to set sound volume to \(clampedVolume)
        """)
    }

    func setPlayerPosition(_ seconds: Double) async throws {
        guard isSpotifyRunning else { return }

        let safePosition = seconds.isFinite ? max(0, seconds) : 0
        try runCommand("""
        tell application id "\(bundleIdentifier)" to set player position to \(safePosition)
        """)
    }

    func openSpotify() async throws {
        try await launchSpotify(activates: true)
    }

    private var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    private func launchSpotify(activates: Bool = false) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw SpotifyBridgeError.spotifyUnavailable
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: SpotifyBridgeError.spotifyLaunchFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func waitForSpotifyLaunch() async throws {
        for _ in 0..<20 {
            if isSpotifyRunning {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw SpotifyBridgeError.spotifyLaunchTimedOut
    }

    private func runCommand(_ source: String) throws {
        _ = try Self.runScript(source)
    }

    private static func runListScript(_ source: String) throws -> [String] {
        let descriptor = try runScript(source)
        let itemCount = descriptor.numberOfItems

        guard itemCount > 0 else {
            return []
        }

        return (1...itemCount).map { index in
            descriptor.atIndex(index)?.stringValue ?? ""
        }
    }

    @discardableResult
    private static func runScript(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        let timedSource = """
        with timeout of \(appleEventTimeoutSeconds) seconds
        \(source)
        end timeout
        """

        guard let script = NSAppleScript(source: timedSource) else {
            throw SpotifyBridgeError.appleScriptFailed("AppleScriptを作成できませんでした。")
        }

        let descriptor = script.executeAndReturnError(&error)
        if let error {
            throw SpotifyScriptParser.bridgeError(from: error)
        }

        return descriptor
    }
}
