import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let frameAutosaveName = NSWindow.FrameAutosaveName("SpotifyControlOverlay")

    private var panel: OverlayPanel?
    private let playerModel = PlayerModel()
    private let singleInstanceGuard = SingleInstanceGuard()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard singleInstanceGuard.acquire() else {
            activateExistingInstance()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        showOverlay()
        playerModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        playerModel.stop()
        singleInstanceGuard.release()
    }

    private func activateExistingInstance() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != currentProcessIdentifier }?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func showOverlay() {
        let size = NSSize(width: OverlayLayout.windowWidth, height: OverlayLayout.windowHeight)
        let origin = Self.defaultOrigin(for: size)
        let panel = OverlayPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .utilityWindow
        Self.restoreFrameIfAvailable(for: panel, fallbackSize: size)
        panel.setFrameAutosaveName(Self.frameAutosaveName)

        let rootView = OverlayView(model: playerModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        self.panel = panel
    }

    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return NSPoint(x: 80, y: 80)
        }

        return NSPoint(
            x: visibleFrame.maxX - size.width - 24,
            y: visibleFrame.maxY - size.height - 24
        )
    }

    private static func restoreFrameIfAvailable(for panel: NSPanel, fallbackSize: NSSize) {
        guard panel.setFrameUsingName(frameAutosaveName) else { return }

        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) }) else {
            panel.setFrameOrigin(defaultOrigin(for: fallbackSize))
            return
        }

        let constrainedFrame = panel.constrainFrameRect(panel.frame, to: screen)
        panel.setFrame(constrainedFrame, display: false)
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct WindowDragRegion: View {
    var onOpenSpotify: () -> Void
    var onOpenAutomationSettings: () -> Void
    var onQuit: () -> Void
    @State private var dragStartWindowOrigin: NSPoint?

    var body: some View {
        Color.clear
            .contentShape(WindowDragHitShape(), eoFill: true)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard let panel = NSApp.windows.first(where: { $0 is OverlayPanel }) else { return }
                        if dragStartWindowOrigin == nil {
                            dragStartWindowOrigin = panel.frame.origin
                        }
                        guard let dragStartWindowOrigin else { return }
                        panel.setFrameOrigin(
                            NSPoint(
                                x: dragStartWindowOrigin.x + value.translation.width,
                                y: dragStartWindowOrigin.y - value.translation.height
                            )
                        )
                    }
                    .onEnded { _ in
                        dragStartWindowOrigin = nil
                    }
            )
            .contextMenu {
                Button("Spotifyを開く", action: onOpenSpotify)
                Button("オートメーション設定を開く", action: onOpenAutomationSettings)
                Divider()
                Button("SpotifyControlを終了", action: onQuit)
            }
            .accessibilityHidden(true)
    }
}

private struct WindowDragHitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        // These holes match the fixed transport, slider, and quit hit targets.
        path.addEllipse(in: CGRect(x: 77, y: 59, width: 26, height: 26))
        path.addEllipse(in: CGRect(x: 106, y: 56, width: 32, height: 32))
        path.addEllipse(in: CGRect(x: 142, y: 59, width: 26, height: 26))
        path.addRoundedRect(
            in: CGRect(x: 227, y: 58, width: 59, height: 28),
            cornerSize: CGSize(width: 14, height: 14)
        )
        path.addEllipse(in: CGRect(x: 285, y: 5, width: 28, height: 28))
        return path
    }
}
