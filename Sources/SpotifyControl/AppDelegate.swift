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

struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

private final class WindowDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
