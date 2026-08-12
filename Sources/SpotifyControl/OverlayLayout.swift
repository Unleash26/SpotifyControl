import Foundation

enum OverlaySizing {
    static let minimumScale: CGFloat = 0.55
    static let defaultScale: CGFloat = 1
    static let maximumScale: CGFloat = 1.35
    static let defaultsKey = "OverlayScale"

    private static let legacyPresetKey = "OverlaySizePreset"

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite else { return defaultScale }
        return min(maximumScale, max(minimumScale, scale))
    }

    static func contentSize(for scale: CGFloat) -> CGSize {
        let scale = clampedScale(scale)
        return CGSize(
            width: OverlayLayout.width * scale,
            height: OverlayLayout.height * scale
        )
    }

    static func windowSize(for scale: CGFloat) -> CGSize {
        let scale = clampedScale(scale)
        return CGSize(
            width: OverlayLayout.windowWidth * scale,
            height: OverlayLayout.windowHeight * scale
        )
    }

    static func scale(for windowSize: CGSize) -> CGFloat {
        guard windowSize.width.isFinite,
              windowSize.height.isFinite,
              windowSize.width > 0,
              windowSize.height > 0
        else {
            return defaultScale
        }

        return clampedScale(
            min(
                windowSize.width / OverlayLayout.windowWidth,
                windowSize.height / OverlayLayout.windowHeight
            )
        )
    }

    static func load(from defaults: UserDefaults = .standard) -> CGFloat {
        if let number = defaults.object(forKey: defaultsKey) as? NSNumber {
            let storedScale = CGFloat(number.doubleValue)
            return storedScale.isFinite ? clampedScale(storedScale) : defaultScale
        }

        switch defaults.string(forKey: legacyPresetKey) {
        case "compact":
            return 0.9
        case "large":
            return 1.2
        default:
            return defaultScale
        }
    }

    static func save(_ scale: CGFloat, to defaults: UserDefaults = .standard) {
        defaults.set(Double(clampedScale(scale)), forKey: defaultsKey)
    }

    static func scaleForBottomRightDrag(
        initialFrame: NSRect,
        startMouseLocation: NSPoint,
        currentMouseLocation: NSPoint,
        visibleFrame: NSRect
    ) -> CGFloat {
        let initialScale = scale(for: initialFrame.size)
        let deltaX = currentMouseLocation.x - startMouseLocation.x
        let deltaY = currentMouseLocation.y - startMouseLocation.y
        let resizeWidth = OverlayLayout.windowWidth
        let resizeHeight = OverlayLayout.windowHeight
        let resizeVectorLengthSquared = resizeWidth * resizeWidth + resizeHeight * resizeHeight
        let scaleDelta = (
            deltaX * resizeWidth - deltaY * resizeHeight
        ) / resizeVectorLengthSquared
        let proposedScale = initialScale + scaleDelta
        let availableScale = min(
            (visibleFrame.maxX - initialFrame.minX) / OverlayLayout.windowWidth,
            (initialFrame.maxY - visibleFrame.minY) / OverlayLayout.windowHeight
        )
        let effectiveMaximum = max(
            minimumScale,
            min(maximumScale, availableScale)
        )

        return min(effectiveMaximum, max(minimumScale, proposedScale))
    }
}

enum OverlayLayout {
    static let width: CGFloat = 380
    static let height: CGFloat = 150
    static let shadowPadding: CGFloat = 14
    static let windowWidth: CGFloat = width + shadowPadding * 2
    static let windowHeight: CGFloat = height + shadowPadding * 2
    static let cornerRadius: CGFloat = 31
}
