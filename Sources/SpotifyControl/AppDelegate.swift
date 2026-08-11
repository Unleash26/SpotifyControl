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
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        Self.restoreFrameIfAvailable(for: panel, fallbackSize: size)

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

        let restoredFrame = panel.frame
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(restoredFrame) }) else {
            panel.setFrameOrigin(defaultOrigin(for: fallbackSize))
            panel.setContentSize(fallbackSize)
            return
        }

        // Borderless, non-resizable panels can restore the saved origin while silently
        // retaining the new size. Clamp explicitly because constrainFrameRect does not
        // reliably move this panel style back inside the visible frame.
        let resizedFrame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: restoredFrame.origin,
            size: fallbackSize,
            visibleFrame: screen.visibleFrame
        )
        panel.setFrame(resizedFrame, display: false)
    }
}

enum OverlayFrameRestoration {
    static func constrainedFrame(
        restoredOrigin: NSPoint,
        size: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        let maximumOriginX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maximumOriginY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        let origin = NSPoint(
            x: min(maximumOriginX, max(visibleFrame.minX, restoredOrigin.x)),
            y: min(maximumOriginY, max(visibleFrame.minY, restoredOrigin.y))
        )
        return NSRect(origin: origin, size: size)
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct WindowDragRegion: NSViewRepresentable {
    var onOpenSpotify: () -> Void
    var onOpenAutomationSettings: () -> Void
    var onQuit: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowDragView()
        view.setAccessibilityElement(false)
        update(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? WindowDragView else { return }
        update(view)
    }

    private func update(_ view: WindowDragView) {
        view.onOpenSpotify = onOpenSpotify
        view.onOpenAutomationSettings = onOpenAutomationSettings
        view.onQuit = onQuit
    }
}

private final class WindowDragView: NSView {
    var onOpenSpotify: (() -> Void)?
    var onOpenAutomationSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Spotifyを開く", action: #selector(openSpotify), keyEquivalent: "")
        menu.addItem(
            withTitle: "オートメーション設定を開く",
            action: #selector(openAutomationSettings),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "SpotifyControlを終了", action: #selector(quit), keyEquivalent: "")

        for item in menu.items where !item.isSeparatorItem {
            item.target = self
        }
        return menu
    }

    @objc private func openSpotify() {
        onOpenSpotify?()
    }

    @objc private func openAutomationSettings() {
        onOpenAutomationSettings?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
