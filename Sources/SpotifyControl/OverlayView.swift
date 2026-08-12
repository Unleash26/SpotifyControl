import AppKit
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: PlayerModel
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let scale = OverlaySizing.scale(for: geometry.size)

            ZStack {
                playerContent
                    .scaleEffect(scale)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onHover { isHovering = $0 }
        .preferredColorScheme(.dark)
    }

    private var playerContent: some View {
        ZStack {
            PlayerBackdrop(snapshot: model.snapshot)
                .allowsHitTesting(false)

            WindowDragRegion(
                onOpenSpotify: model.openSpotify,
                onOpenAutomationSettings: model.openAutomationSettings,
                onQuit: { NSApp.terminate(nil) }
            )
            .frame(width: OverlayLayout.windowWidth, height: OverlayLayout.windowHeight)

            VStack(alignment: .leading, spacing: 0) {
                TrackMetadata(snapshot: model.snapshot)
                    .padding(.trailing, 24)
                    .allowsHitTesting(false)

                Spacer(minLength: 8)

                PlaybackTimeline(model: model)

                Spacer(minLength: 5)

                TransportControls(model: model)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)
            .frame(width: OverlayLayout.width, height: OverlayLayout.height)

            QuitButton()
                .opacity(isHovering ? 0.78 : 0)
                .allowsHitTesting(isHovering)
                .accessibilityHidden(!isHovering)
                .padding(9)
                .frame(
                    width: OverlayLayout.width,
                    height: OverlayLayout.height,
                    alignment: .topTrailing
                )
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .frame(width: OverlayLayout.windowWidth, height: OverlayLayout.windowHeight)
    }
}

private struct TrackMetadata: View {
    var snapshot: SpotifySnapshot
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.panelText)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(secondaryText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    accessibilityContrast == .increased
                        ? Color.white
                        : Color.panelSecondaryText
                )
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .shadow(color: .black.opacity(0.48), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
    }

    private var secondaryText: String {
        let values = [snapshot.artist, snapshot.album]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? snapshot.state.compactStatusLabel : values.joined(separator: " · ")
    }

}

private struct PlaybackTimeline: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @State private var showsKeyboardFocus = false
    @FocusState private var isTimelineFocused: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: !model.snapshot.state.isPlaying || reduceMotion
            )
        ) { context in
            let duration = model.snapshot.durationSeconds
            let position = model.displayedPosition(at: context.date)
            let canSeek = duration > 0 && model.snapshot.state.canControlTrack
            let progress = duration > 0 ? min(1, max(0, position / duration)) : 0
            let phase = model.snapshot.state.isPlaying && !reduceMotion
                ? LiquidRibbonProfile.phase(at: context.date)
                : 0

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    LiquidRibbonRail(
                        progress: progress,
                        phase: phase,
                        isPlaying: model.snapshot.state.isPlaying,
                        reduceMotion: reduceMotion,
                        increasedContrast: accessibilityContrast == .increased,
                        showsThumb: canSeek
                    )
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged {
                                updatePosition(
                                    at: $0.location.x,
                                    width: geometry.size.width,
                                    duration: duration,
                                    isEditing: true
                                )
                            }
                            .onEnded {
                                showsKeyboardFocus = false
                                updatePosition(
                                    at: $0.location.x,
                                    width: geometry.size.width,
                                    duration: duration,
                                    isEditing: false
                                )
                            }
                    )
                }
                .frame(height: 24)

                HStack {
                    Text(formattedTime(position))
                    Spacer()
                    Text(formattedTime(duration))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    accessibilityContrast == .increased
                        ? Color.white
                        : Color.panelSecondaryText
                )
                .allowsHitTesting(false)
            }
            .opacity(canSeek ? 1 : 0.52)
            .allowsHitTesting(canSeek)
            .timelineKeyboardFocusable(canSeek)
            .focused($isTimelineFocused)
            .overlay {
                if isTimelineFocused && showsKeyboardFocus {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.white.opacity(0.86), lineWidth: 1.5)
                        .padding(-4)
                }
            }
            .onMoveCommand { direction in
                guard canSeek else { return }
                showsKeyboardFocus = true
                let step = max(5, duration * 0.01)
                switch direction {
                case .left, .down:
                    model.setPlaybackPosition(position - step, isEditing: false)
                case .right, .up:
                    model.setPlaybackPosition(position + step, isEditing: false)
                default:
                    break
                }
            }
            .onChange(of: isTimelineFocused) { focused in
                if !focused {
                    showsKeyboardFocus = false
                }
            }
            .accessibilityElement()
            .accessibilityLabel("再生位置")
            .accessibilityValue("\(spokenTime(position))、全体\(spokenTime(duration))")
            .accessibilityHidden(!canSeek)
            .accessibilityAdjustableAction { direction in
                let step = max(5, duration * 0.01)
                switch direction {
                case .increment:
                    model.setPlaybackPosition(position + step, isEditing: false)
                case .decrement:
                    model.setPlaybackPosition(position - step, isEditing: false)
                @unknown default:
                    break
                }
            }
            .help(
                canSeek
                    ? "再生位置、\(spokenTime(position))、全体\(spokenTime(duration))。ドラッグまたは左右キーで変更"
                    : "再生位置を取得できません"
            )
        }
    }

    private func updatePosition(
        at location: CGFloat,
        width: CGFloat,
        duration: Double,
        isEditing: Bool
    ) {
        guard width > 0, duration > 0 else { return }
        let fraction = min(1, max(0, location / width))
        model.setPlaybackPosition(Double(fraction) * duration, isEditing: isEditing)
    }

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func spokenTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0秒" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)時間")
        }
        if minutes > 0 {
            parts.append("\(minutes)分")
        }
        if remainingSeconds > 0 || parts.isEmpty {
            parts.append("\(remainingSeconds)秒")
        }
        return parts.joined()
    }
}

private struct LiquidRibbonRail: View {
    var progress: Double
    var phase: Double
    var isPlaying: Bool
    var reduceMotion: Bool
    var increasedContrast: Bool
    var showsThumb: Bool

    var body: some View {
        // A synchronous canvas is deliberate here. Asynchronous Canvas rendering can
        // clear sibling layers inside a transparent NSPanel during timeline updates.
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let centerY = max(0, min(size.height - 7, size.height / 2 + 3))
            let clampedProgress = progress.isFinite ? min(1, max(0, progress)) : 0
            let activeWidth = size.width * CGFloat(clampedProgress)
            let railHeight: CGFloat = increasedContrast ? 6 : 5.5
            let railTop = centerY - railHeight / 2
            let railBottom = centerY + railHeight / 2
            let railRect = CGRect(x: 0, y: railTop, width: size.width, height: railHeight)
            context.fill(
                Path(roundedRect: railRect, cornerRadius: railHeight / 2),
                with: .color(.white.opacity(increasedContrast ? 0.60 : 0.34))
            )

            if activeWidth > 0 {
                let maximumLift: CGFloat = increasedContrast ? 9.75 : 9.25
                let capRadius = min(railHeight / 2, activeWidth / 2)
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: 0, y: centerY))
                ribbon.addQuadCurve(
                    to: CGPoint(x: capRadius, y: railTop),
                    control: CGPoint(x: 0, y: railTop)
                )

                for x in stride(from: capRadius, through: activeWidth, by: 1) {
                    let amount = LiquidRibbonProfile.amount(
                        at: Double(x),
                        trackWidth: Double(size.width),
                        activeWidth: Double(activeWidth),
                        phase: phase,
                        isAnimated: isPlaying && !reduceMotion
                    )
                    ribbon.addLine(
                        to: CGPoint(x: x, y: railTop - maximumLift * CGFloat(amount))
                    )
                }

                ribbon.addLine(to: CGPoint(x: activeWidth, y: railTop))
                ribbon.addLine(to: CGPoint(x: activeWidth, y: railBottom))
                ribbon.addLine(to: CGPoint(x: capRadius, y: railBottom))
                ribbon.addQuadCurve(
                    to: CGPoint(x: 0, y: centerY),
                    control: CGPoint(x: 0, y: railBottom)
                )
                ribbon.closeSubpath()

                context.fill(
                    ribbon,
                    with: .color(
                        increasedContrast
                            ? Color.panelText
                            : Color.panelProgressActive
                    )
                )
            }

            if showsThumb {
                let thumbSize: CGFloat = 13
                let thumbRect = CGRect(
                    x: min(size.width - thumbSize, max(0, activeWidth - thumbSize / 2)),
                    y: centerY - thumbSize / 2,
                    width: thumbSize,
                    height: thumbSize
                )
                context.fill(
                    Path(ellipseIn: thumbRect.offsetBy(dx: 0, dy: 1.5)),
                    with: .color(.black.opacity(0.30))
                )
                context.fill(
                    Path(ellipseIn: thumbRect),
                    with: .color(increasedContrast ? Color.panelText : Color.panelProgressThumb)
                )
                context.stroke(
                    Path(ellipseIn: thumbRect),
                    with: .color(.white.opacity(0.42)),
                    lineWidth: 0.75
                )
            }
        }
    }
}

private struct TransportControls: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
        HStack(spacing: 27) {
            TransportButton(
                systemName: "backward.end.fill",
                label: "前の曲",
                size: 17,
                isEnabled: model.snapshot.state.canControlTrack,
                action: model.previousTrack
            )

            TransportButton(
                systemName: primaryControlIcon,
                label: primaryControlLabel,
                size: 22,
                isPrimary: true,
                isEnabled: model.snapshot.state != .unavailable,
                action: primaryAction
            )

            TransportButton(
                systemName: "forward.end.fill",
                label: "次の曲",
                size: 17,
                isEnabled: model.snapshot.state.canControlTrack,
                action: model.nextTrack
            )
        }
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

    private func primaryAction() {
        if model.snapshot.state == .permissionDenied {
            model.openAutomationSettings()
        } else {
            model.playPause()
        }
    }
}

private struct TransportButton: View {
    var systemName: String
    var label: String
    var size: CGFloat
    var isPrimary = false
    var isEnabled: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.system(size: size, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.panelText)
                .frame(width: isPrimary ? 46 : 38, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(isHovering ? 0.15 : 0.001))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.34)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct PlayerBackdrop: View {
    var snapshot: SpotifySnapshot
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    var body: some View {
        ZStack {
            fallback

            if let artworkURL = snapshot.artworkURL {
                AsyncImage(url: artworkURL, transaction: Transaction(animation: nil)) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: OverlayLayout.width, height: OverlayLayout.height)
                .clipped()
            }

            Color.black.opacity(accessibilityContrast == .increased ? 0.58 : 0.44)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.54)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.black.opacity(0.08), .clear, Color.black.opacity(0.16)],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(accessibilityContrast == .increased ? 0.52 : 0.36),
                    Color.black.opacity(accessibilityContrast == .increased ? 0.24 : 0.14),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
        .frame(width: OverlayLayout.width, height: OverlayLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous))
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: placeholderColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: snapshot.state == .unavailable ? "exclamationmark.triangle.fill" : "music.note")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 118, y: -10)
        }
    }

    private var placeholderColors: [Color] {
        switch snapshot.state {
        case .playing:
            return [Color(red: 0.06, green: 0.43, blue: 0.26), Color(red: 0.025, green: 0.14, blue: 0.14)]
        case .paused:
            return [Color(red: 0.25, green: 0.29, blue: 0.34), Color(red: 0.08, green: 0.09, blue: 0.12)]
        case .unavailable, .permissionDenied, .connectionError:
            return [Color(red: 0.40, green: 0.16, blue: 0.20), Color(red: 0.12, green: 0.06, blue: 0.09)]
        default:
            return [Color(red: 0.17, green: 0.20, blue: 0.24), Color(red: 0.055, green: 0.065, blue: 0.08)]
        }
    }
}

private struct QuitButton: View {
    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.panelText.opacity(0.82))
                .frame(width: 25, height: 25)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel("終了")
        .help("SpotifyControlを終了")
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
    static let panelText = Color(red: 0.97, green: 0.975, blue: 0.96)
    static let panelSecondaryText = Color.white.opacity(0.72)
    static let panelProgressActive = Color(red: 0.70, green: 0.81, blue: 0.95)
    static let panelProgressThumb = Color(red: 0.84, green: 0.90, blue: 0.99)
}

private extension View {
    @ViewBuilder
    func timelineKeyboardFocusable(_ isFocusable: Bool) -> some View {
        if #available(macOS 14.0, *) {
            focusable(isFocusable)
                .focusEffectDisabled()
        } else {
            // Ventura keeps the native keyboard focus effect. The panel only
            // becomes key when an actual input control needs it.
            focusable(isFocusable)
        }
    }
}
