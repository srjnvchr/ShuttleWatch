import TrackingKit

/// Runs TrackingKit on live camera frames and hands the result to the overlay (FR-27).
/// The same tracking code runs on recordings in the Mac track-video tool, so fixes are
/// tested on real footage before they reach the phone.
actor Tracker {
    private let overlay: TrackingOverlay
    private let court = CourtTracker()

    init(overlay: TrackingOverlay) {
        self.overlay = overlay
    }

    func reset() {
        court.reset()
        publish(TrackingFrame())
    }

    func analyze(_ frame: SendableSampleBuffer) {
        guard let result = court.process(frame.buffer) else { return }
        publish(result.frame)
    }

    private func publish(_ frame: TrackingFrame) {
        Task { @MainActor [overlay] in overlay.show(frame) }
    }
}
