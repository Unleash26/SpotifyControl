import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let frameAutosaveIdentifier = "SpotifyControlOverlay"
    private static let frameAutosaveName = NSWindow.FrameAutosaveName(frameAutosaveIdentifier)
    private static let frameAutosaveDefaultsKey = "NSWindow Frame \(frameAutosaveIdentifier)"

    private var panel: OverlayPanel?
    private var overlayScale = OverlaySizing.load()
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
        saveOverlayGeometry()
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
        let size = OverlaySizing.windowSize(for: overlayScale)
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
        if #unavailable(macOS 14.0) {
            // Ventura has no focusEffectDisabled(). Keep background dragging from
            // making the nonactivating panel key while preserving real controls.
            panel.becomesKeyOnlyIfNeeded = true
        }
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .utilityWindow
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        Self.restoreFrameIfAvailable(for: panel, fallbackSize: size)

        let rootView = makeRootView()
        let hostingView = OverlayHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let contentContainer = OverlayContentView(frame: NSRect(origin: .zero, size: size))
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor
        contentContainer.addSubview(hostingView)

        let resizeHandleSize: CGFloat = 36
        let resizeHandle = WindowResizeHandleView(
            frame: NSRect(
                x: size.width - resizeHandleSize,
                y: 0,
                width: resizeHandleSize,
                height: resizeHandleSize
            )
        )
        resizeHandle.setAccessibilityElement(true)
        resizeHandle.setAccessibilityRole(.handle)
        resizeHandle.setAccessibilityLabel("サイズを変更")
        resizeHandle.setAccessibilityHelp("右下をドラッグしてサイズを変更します")
        resizeHandle.wantsLayer = true
        resizeHandle.layer?.backgroundColor = NSColor.clear.cgColor
        resizeHandle.autoresizingMask = [.minXMargin, .maxYMargin]
        resizeHandle.onResizeEnded = { [weak self] scale in
            self?.overlayScale = scale
            self?.saveOverlayGeometry()
        }
        contentContainer.addSubview(resizeHandle, positioned: .above, relativeTo: hostingView)
        contentContainer.resizeHandle = resizeHandle

        panel.contentView = contentContainer
        panel.orderFrontRegardless()

        self.panel = panel
    }

    private func makeRootView() -> OverlayView {
        OverlayView(model: playerModel)
    }

    private func saveOverlayGeometry() {
        guard let panel else { return }
        overlayScale = OverlaySizing.scale(for: panel.frame.size)
        OverlaySizing.save(overlayScale)
        panel.saveFrame(usingName: Self.frameAutosaveName)
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
        let savedWindowFrame = OverlayFrameRestoration.savedWindowFrame(
            from: UserDefaults.standard.string(forKey: frameAutosaveDefaultsKey)
        )
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
        let migratedOrigin = OverlayFrameRestoration.originPreservingVisibleCard(
            restoredOrigin: restoredFrame.origin,
            savedWindowFrame: savedWindowFrame,
            currentWindowSize: fallbackSize
        )
        let resizedFrame = OverlayFrameRestoration.constrainedFrame(
            restoredOrigin: migratedOrigin,
            size: fallbackSize,
            visibleFrame: screen.visibleFrame
        )
        panel.setFrame(resizedFrame, display: false)
    }
}

enum OverlayFrameRestoration {
    private static let legacyShadowPadding: CGFloat = 14

    static func savedWindowFrame(from frameAutosaveValue: String?) -> NSRect? {
        guard let frameAutosaveValue else { return nil }
        let values = frameAutosaveValue
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Double($0) }
        guard values.count >= 4,
              values[0].isFinite,
              values[1].isFinite,
              values[2].isFinite,
              values[3].isFinite,
              values[2] > 0,
              values[3] > 0
        else {
            return nil
        }
        return NSRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    static func originPreservingVisibleCard(
        restoredOrigin: NSPoint,
        savedWindowFrame: NSRect?,
        currentWindowSize: NSSize
    ) -> NSPoint {
        guard let savedWindowFrame,
              currentWindowSize.width > 0,
              currentWindowSize.height > 0
        else {
            return restoredOrigin
        }

        let widthScale = currentWindowSize.width / OverlayLayout.width
        let heightScale = currentWindowSize.height / OverlayLayout.height
        guard widthScale.isFinite,
              heightScale.isFinite,
              abs(widthScale - heightScale) < 0.001
        else {
            return restoredOrigin
        }

        let legacyPadding = legacyShadowPadding * widthScale
        let expectedLegacySize = NSSize(
            width: currentWindowSize.width + legacyPadding * 2,
            height: currentWindowSize.height + legacyPadding * 2
        )
        let tolerance: CGFloat = 1.5
        guard abs(savedWindowFrame.width - expectedLegacySize.width) <= tolerance,
              abs(savedWindowFrame.height - expectedLegacySize.height) <= tolerance
        else {
            return restoredOrigin
        }

        // The old frame placed the visible card inside a transparent shadow gutter.
        // Shift by that gutter once so removing it does not move the card on screen.
        return NSPoint(
            x: savedWindowFrame.minX + legacyPadding,
            y: savedWindowFrame.minY + legacyPadding
        )
    }

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

private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class OverlayContentView: NSView {
    weak var resizeHandle: NSView?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let resizeHandle, resizeHandle.frame.contains(point) {
            return resizeHandle
        }
        return super.hitTest(point)
    }
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
        guard let window else { return }
        window.makeFirstResponder(nil)
        window.performDrag(with: event)
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

private final class WindowResizeHandleView: NSView {
    var onResizeEnded: ((CGFloat) -> Void)?

    private var initialFrame: NSRect?
    private var startMouseLocation: NSPoint?
    private var resizeVisibleFrame: NSRect?
    private var currentScale: CGFloat?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installResizeIndicator()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installResizeIndicator()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // Keep the source compatible with the older macOS SDK used by CI.
        // The always-visible diagonal badge communicates the two-axis gesture.
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.makeFirstResponder(nil)
        initialFrame = window.frame
        startMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        resizeVisibleFrame = window.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(window.frame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        currentScale = OverlaySizing.scale(for: window.frame.size)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let initialFrame,
              let startMouseLocation,
              let resizeVisibleFrame
        else {
            return
        }

        let scale = OverlaySizing.scaleForBottomRightDrag(
            initialFrame: initialFrame,
            startMouseLocation: startMouseLocation,
            currentMouseLocation: window.convertPoint(toScreen: event.locationInWindow),
            visibleFrame: resizeVisibleFrame
        )
        let size = OverlaySizing.windowSize(for: scale)
        currentScale = scale
        window.setFrame(
            NSRect(
                x: initialFrame.minX,
                y: initialFrame.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            initialFrame = nil
            startMouseLocation = nil
            resizeVisibleFrame = nil
            currentScale = nil
        }

        guard let currentScale else { return }
        onResizeEnded?(currentScale)
    }

    private func installResizeIndicator() {
        let badge = NSView(frame: NSRect(x: 12, y: 4, width: 18, height: 18))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        badge.layer?.cornerRadius = 9
        badge.setAccessibilityElement(false)

        let iconView = NSImageView(frame: NSRect(x: 4, y: 4, width: 10, height: 10))
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        iconView.image = NSImage(
            systemSymbolName: "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.58)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setAccessibilityElement(false)

        badge.addSubview(iconView)
        addSubview(badge)
    }
}
