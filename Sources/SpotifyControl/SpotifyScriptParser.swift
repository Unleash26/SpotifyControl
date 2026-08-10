import Foundation

enum SpotifyScriptParser {
    static func snapshot(from values: [String]) throws -> SpotifySnapshot {
        guard values.count == 6 else {
            throw SpotifyBridgeError.invalidResponse
        }

        let state = PlaybackState(rawValue: values[0]) ?? .unknown
        let volume = min(100, max(0, Int(values[5]) ?? 50))
        let title = values[1].nilIfEmpty ?? "曲情報なし"
        let artist = values[2].nilIfEmpty ?? state.displayText
        let artworkURL = values[4].nilIfEmpty.flatMap(URL.init(string:))

        return SpotifySnapshot(
            state: state,
            title: title,
            artist: artist,
            album: values[3],
            artworkURL: artworkURL,
            volume: volume,
            message: nil
        )
    }

    static func bridgeError(from error: NSDictionary) -> SpotifyBridgeError {
        let errorNumber = error[NSAppleScript.errorNumber] as? Int
        if errorNumber == -1743 {
            return .automationPermissionDenied
        }
        if errorNumber == -1712 {
            return .appleScriptTimedOut
        }

        let message = error[NSAppleScript.errorMessage] as? String
            ?? error.description
        return .appleScriptFailed(message)
    }
}

extension PlaybackState {
    var displayText: String {
        switch self {
        case .playing:
            return "再生中"
        case .paused:
            return "一時停止中"
        case .stopped:
            return "停止中"
        case .notRunning:
            return "Spotify未起動"
        case .unavailable:
            return "Spotify未インストール"
        case .permissionDenied:
            return "操作許可が必要"
        case .connectionError:
            return "接続エラー"
        case .unknown:
            return "状態不明"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
