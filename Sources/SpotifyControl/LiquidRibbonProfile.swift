import Foundation

enum LiquidRibbonProfile {
    static let loopDuration: TimeInterval = 2.1

    private static let lobes = [
        Lobe(center: 0.15, travel: 0.045, spread: 0.082, amplitude: 0.96, offset: 0.25),
        Lobe(center: 0.39, travel: 0.052, spread: 0.096, amplitude: 0.82, offset: 2.05),
        Lobe(center: 0.66, travel: 0.055, spread: 0.092, amplitude: 0.88, offset: 4.10),
        Lobe(center: 0.90, travel: 0.038, spread: 0.078, amplitude: 0.74, offset: 5.35)
    ]

    static func phase(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: loopDuration)
        return elapsed * (2 * .pi / loopDuration)
    }

    static func amount(
        at x: Double,
        trackWidth: Double,
        activeWidth: Double,
        phase: Double,
        isAnimated: Bool
    ) -> Double {
        guard trackWidth.isFinite,
              activeWidth.isFinite,
              x.isFinite,
              trackWidth > 0,
              activeWidth > 0
        else {
            return 0
        }

        let clampedActiveWidth = min(trackWidth, max(0, activeWidth))
        let clampedX = min(clampedActiveWidth, max(0, x))
        let normalizedX = clampedX / trackWidth
        let motionPhase = isAnimated && phase.isFinite ? phase : 0

        // Four broad, slowly morphing lobes span the complete rail. The elapsed
        // section reveals them progressively, matching One UI's liquid ribbon
        // without pretending to visualize the current audio signal.
        let fourthPowerSum = lobes.reduce(0.0) { partialResult, lobe in
            let center = lobe.center + lobe.travel * sin(motionPhase + lobe.offset)
            let breathing = 0.88 + 0.12 * sin(motionPhase * 2 + lobe.offset * 0.7)
            let spread = lobe.spread * (0.92 + 0.08 * sin(motionPhase + lobe.offset + 1.1))
            let distance = (normalizedX - center) / max(0.001, spread)
            let gaussian = exp(-0.5 * distance * distance)
            let value = max(0, lobe.amplitude * breathing * gaussian)
            let squaredValue = value * value
            return partialResult + squaredValue * squaredValue
        }

        let lobeAmount = min(1, sqrt(sqrt(fourthPowerSum)))
        let edgeRamp = min(14, max(0.5, clampedActiveWidth / 2))
        let leadingEnvelope = smoothStep(min(1, clampedX / edgeRamp))
        let trailingEnvelope = smoothStep(min(1, (clampedActiveWidth - clampedX) / edgeRamp))
        let widthEnvelope = smoothStep(min(1, clampedActiveWidth / 18))

        return min(1, max(0, lobeAmount * leadingEnvelope * trailingEnvelope * widthEnvelope))
    }

    private static func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private struct Lobe {
        var center: Double
        var travel: Double
        var spread: Double
        var amplitude: Double
        var offset: Double
    }
}
