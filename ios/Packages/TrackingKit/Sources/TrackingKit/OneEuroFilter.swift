import Foundation

/// Smooths a jittery value without making fast movement lag (the "1€ filter",
/// Casiez, Roussel and Vogel, CHI 2012). When the value is still, it smooths strongly.
/// When the value moves fast, it smooths lightly, so it keeps up.
struct OneEuroFilter: Sendable {
    /// Smoothing when still, in hertz. Lower is smoother.
    let minimumCutoff: Double
    /// How much faster movement reduces smoothing.
    let speedCoefficient: Double
    /// Smoothing of the speed estimate itself, in hertz.
    let speedCutoff: Double

    private var value: Double?
    private var speed = 0.0
    private var lastTime: TimeInterval?

    init(minimumCutoff: Double = 1.0, speedCoefficient: Double = 8.0, speedCutoff: Double = 1.0) {
        self.minimumCutoff = minimumCutoff
        self.speedCoefficient = speedCoefficient
        self.speedCutoff = speedCutoff
    }

    mutating func filter(_ raw: Double, at time: TimeInterval) -> Double {
        guard let previous = value, let lastTime, time > lastTime else {
            value = raw
            lastTime = time
            return raw
        }
        let elapsed = time - lastTime
        let rawSpeed = (raw - previous) / elapsed
        speed += Self.alpha(cutoff: speedCutoff, elapsed: elapsed) * (rawSpeed - speed)
        let cutoff = minimumCutoff + speedCoefficient * abs(speed)
        let smoothed = previous + Self.alpha(cutoff: cutoff, elapsed: elapsed) * (raw - previous)
        value = smoothed
        self.lastTime = time
        return smoothed
    }

    private static func alpha(cutoff: Double, elapsed: Double) -> Double {
        let timeConstant = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + timeConstant / elapsed)
    }
}
