import AppKit
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: PlayerModel
    @State private var isHovering = false

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                ArtworkView(url: model.snapshot.artworkURL, state: model.snapshot.state)

                VStack(alignment: .leading, spacing: 7) {
                    HeaderView(snapshot: model.snapshot)

                    HStack(spacing: 10) {
                        TransportControls(model: model)
                        Spacer(minLength: 4)
                        VolumeControl(model: model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 11)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .frame(width: OverlayLayout.width, height: OverlayLayout.height)
            .background(PanelBackground())
            .overlay(alignment: .topTrailing) {
                QuitButton()
                    .opacity(isHovering ? 1 : 0.52)
                    .padding(7)
            }
        }
        .frame(width: OverlayLayout.windowWidth, height: OverlayLayout.windowHeight)
        .overlay(alignment: .topLeading) {
            WindowDragRegion()
                .frame(width: 190, height: 20)
                .padding(.leading, 86)
                .padding(.top, 2)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Spotifyを開く") {
                model.openSpotify()
            }
            Button("オートメーション設定を開く") {
                model.openAutomationSettings()
            }
            Divider()
            Button("SpotifyControlを終了") {
                NSApp.terminate(nil)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ArtworkView: View {
    var url: URL?
    var state: PlaybackState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.16))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: OverlayLayout.artworkSize, height: OverlayLayout.artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.30), radius: 10, x: 0, y: 7)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: placeholderColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: state == .unavailable ? "exclamationmark.triangle.fill" : "music.note")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
        }
    }

    private var placeholderColors: [Color] {
        switch state {
        case .playing:
            return [Color(red: 0.12, green: 0.74, blue: 0.32), Color(red: 0.04, green: 0.42, blue: 0.22)]
        case .paused:
            return [Color(red: 0.48, green: 0.52, blue: 0.58), Color(red: 0.23, green: 0.26, blue: 0.31)]
        case .unavailable:
            return [Color(red: 0.82, green: 0.20, blue: 0.20), Color(red: 0.42, green: 0.12, blue: 0.18)]
        default:
            return [Color(red: 0.23, green: 0.24, blue: 0.27), Color(red: 0.08, green: 0.09, blue: 0.10)]
        }
    }
}

private struct HeaderView: View {
    var snapshot: SpotifySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(snapshot.state.isPlaying ? Color.spotifyGreen : Color.secondary.opacity(0.65))
                    .frame(width: 5, height: 5)

                Text(snapshot.state.compactStatusLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.panelMutedText)
                    .lineLimit(1)
            }

            Text(snapshot.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.panelText)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(snapshot.artist)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.panelSecondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.trailing, 14)
    }
}

private struct TransportControls: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
        HStack(spacing: 7) {
            Button {
                model.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .accessibilityLabel("前の曲")
            .help("前の曲")
            .disabled(!model.snapshot.state.canControlTrack)

            Button {
                if model.snapshot.state == .permissionDenied {
                    model.openAutomationSettings()
                } else {
                    model.playPause()
                }
            } label: {
                Image(systemName: primaryControlIcon)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(Color.panelText.opacity(0.96))
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.38), lineWidth: 1)
                            }
                    }
                    .foregroundStyle(Color.panelInk)
                    .clipShape(Circle())
            }
            .accessibilityLabel(primaryControlLabel)
            .help(primaryControlLabel)
            .disabled(model.snapshot.state == .unavailable)

            Button {
                model.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .accessibilityLabel("次の曲")
            .help("次の曲")
            .disabled(!model.snapshot.state.canControlTrack)
        }
        .buttonStyle(TransportButtonStyle())
    }

    private var primaryControlIcon: String {
        if model.snapshot.state == .permissionDenied {
            return "gearshape.fill"
        }
        return model.snapshot.state.isPlaying ? "pause.fill" : "play.fill"
    }

    private var primaryControlLabel: String {
        if model.snapshot.state == .permissionDenied {
            return "オートメーション設定を開く"
        }
        return model.snapshot.state.isPlaying ? "一時停止" : "再生"
    }
}

private struct VolumeControl: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.panelSecondaryText)
                .frame(width: 13)

            Slider(
                value: Binding(
                    get: { model.volume },
                    set: { model.setVolume($0, isEditing: true) }
                ),
                in: 0...100,
                step: 1,
                onEditingChanged: { editing in
                    model.setVolume(model.volume, isEditing: editing)
                }
            )
            .controlSize(.small)
            .tint(.spotifyGreen)
            .frame(width: 54)
            .accessibilityLabel("Spotifyの音量")
            .accessibilityValue("\(Int(model.volume.rounded()))パーセント")
            .disabled(!model.snapshot.state.canControlTrack)

            Text("\(Int(model.volume.rounded()))")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.panelSecondaryText)
                .monospacedDigit()
                .frame(width: 18, alignment: .trailing)
        }
    }
}

private struct QuitButton: View {
    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.panelText.opacity(0.46))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("終了")
        .help("SpotifyControlを終了")
    }
}

private struct TransportButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.panelText)
            .opacity(isEnabled ? (configuration.isPressed ? 0.58 : 1) : 0.30)
            .contentShape(Circle())
    }
}

private struct PanelBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous)
                .fill(Color.panelGlassTint.opacity(0.055))

            RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.070),
                            Color.black.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)

        }
        .frame(width: OverlayLayout.width, height: OverlayLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        view.isEmphasized = false
        view.alphaValue = 0.84
        view.wantsLayer = true
        view.layer?.cornerRadius = OverlayLayout.cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = 0.84
        view.layer?.cornerRadius = OverlayLayout.cornerRadius
        view.layer?.masksToBounds = true
    }
}

private extension PlaybackState {
    var compactStatusLabel: String {
        switch self {
        case .playing:
            return "再生中"
        case .paused:
            return "一時停止"
        case .stopped:
            return "停止中"
        case .notRunning:
            return "未起動"
        case .unavailable:
            return "未インストール"
        case .permissionDenied:
            return "操作許可が必要"
        case .connectionError:
            return "接続エラー"
        case .unknown:
            return "接続中"
        }
    }

    var canControlTrack: Bool {
        switch self {
        case .playing, .paused, .stopped:
            return true
        case .notRunning, .unavailable, .permissionDenied, .connectionError, .unknown:
            return false
        }
    }
}

private extension Color {
    static let spotifyGreen = Color(red: 0.12, green: 0.73, blue: 0.33)
    static let panelInk = Color(red: 0.02, green: 0.025, blue: 0.025)
    static let panelText = Color(red: 0.96, green: 0.97, blue: 0.94)
    static let panelSecondaryText = Color(red: 0.70, green: 0.73, blue: 0.68)
    static let panelMutedText = Color(red: 0.58, green: 0.66, blue: 0.57)
    static let panelGlassTint = Color(red: 0.055, green: 0.075, blue: 0.065)
}
