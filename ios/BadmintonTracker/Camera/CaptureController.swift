import AVFoundation
import Observation
import UIKit

/// Owns the back camera for the whole app (FR-11, FR-27, FR-29).
/// The camera runs while the camera view is open or a recording is going,
/// so recording carries on when you switch back to the scoring screen.
@Observable
final class CaptureController {
    enum Status: Equatable {
        case idle
        case running
        /// No back camera, for example in the simulator.
        case unavailable
        /// The user said no to camera access. It can be changed in Settings.
        case denied
    }

    private(set) var status = Status.idle
    private(set) var device: AVCaptureDevice?
    /// When the current recording's first frame was captured. Nil when not recording.
    private(set) var recordingStartedAt: Date?
    var isRecording: Bool { recordingStartedAt != nil }

    /// Shows player halos and the shuttle on the camera view. Visual only.
    var isTrackingEnabled = false {
        didSet {
            let enabled = isTrackingEnabled
            Task { await processor.setTracking(enabled) }
            if !enabled { overlay.clear() }
        }
    }

    let session = AVCaptureSession()
    let overlay: TrackingOverlay

    @ObservationIgnored private let processor: FrameProcessor
    @ObservationIgnored private let frameDelegate: FrameDelegate
    @ObservationIgnored private let output = AVCaptureVideoDataOutput()
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservation: NSKeyValueObservation?
    @ObservationIgnored private var recordingURL: URL?
    @ObservationIgnored private var holds = 0
    @ObservationIgnored private var isConfigured = false

    init() {
        let overlay = TrackingOverlay()
        self.overlay = overlay
        processor = FrameProcessor(tracker: Tracker(overlay: overlay))
        frameDelegate = FrameDelegate(processor: processor)
    }

    // MARK: Running

    /// Keeps the camera on. Each call needs a matching `release()`.
    func acquire() async {
        holds += 1
        if holds == 1 {
            await start()
        }
    }

    func release() async {
        holds = max(0, holds - 1)
        if holds == 0 && status == .running {
            await Self.run(session, start: false)
            status = .idle
        }
    }

    private func start() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            status = .unavailable
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            status = .denied
            return
        }
        if !isConfigured {
            guard configure(with: device) else {
                status = .unavailable
                return
            }
        }
        self.device = device
        await Self.run(session, start: true)
        status = holds > 0 ? .running : .idle
    }

    private func configure(with device: AVCaptureDevice) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return false
        }
        session.sessionPreset = .inputPriority
        session.addInput(input)
        Self.selectFullHD60(on: device)

        output.alwaysDiscardsLateVideoFrames = false
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        output.setSampleBufferDelegate(frameDelegate, queue: processor.queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        // Keep frames level with the horizon, so recordings and tracking match what the preview shows.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        applyCaptureRotation()
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture) { [weak self] _, _ in
            Task { @MainActor in self?.applyCaptureRotation() }
        }

        isConfigured = true
        return true
    }

    /// NFR-03: 60 frames a second. 1080p keeps files and heat manageable.
    private static func selectFullHD60(on device: AVCaptureDevice) {
        let format = device.formats.first { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.width == 1920 && size.height == 1080
                && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
        }
        guard let format, (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = format
        let frameDuration = CMTime(value: 1, timescale: 60)
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        device.unlockForConfiguration()
    }

    /// Follows the phone's rotation, except during a recording: a video keeps one orientation.
    private func applyCaptureRotation() {
        guard !isRecording, let coordinator = rotationCoordinator, let connection = output.connection(with: .video) else {
            return
        }
        let angle = coordinator.videoRotationAngleForHorizonLevelCapture
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    /// Starting and stopping block for a moment, so they run off the main thread.
    private static func run(_ session: AVCaptureSession, start: Bool) async {
        // AVCaptureSession is not marked Sendable, but Apple documents startRunning and
        // stopRunning as safe to call from a background queue. Only these two calls cross over.
        nonisolated(unsafe) let session = session
        await Task.detached {
            if start {
                session.startRunning()
            } else {
                session.stopRunning()
            }
        }.value
    }

    // MARK: Recording (FR-11)

    /// Starts recording into `folder`. Returns false if the camera is not available.
    func startRecording(in folder: URL) async -> Bool {
        guard !isRecording else { return true }
        await acquire()
        guard status == .running else {
            await release()
            return false
        }
        applyCaptureRotation()
        let url = folder.appending(path: "video \(MatchLabels.localStamp(.now, timeSeparator: "", seconds: true)).mov")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            recordingStartedAt = try await processor.startRecording(to: url)
            recordingURL = url
            // A phone on a tripod must not lock its screen mid-match.
            UIApplication.shared.isIdleTimerDisabled = true
            return true
        } catch {
            await release()
            return false
        }
    }

    /// Stops the recording and returns what was saved, or nil if nothing was.
    func stopRecording() async -> RecordingSegment? {
        guard let startedAt = recordingStartedAt else { return nil }
        let savedURL = await processor.stopRecording()
        recordingStartedAt = nil
        recordingURL = nil
        UIApplication.shared.isIdleTimerDisabled = false
        applyCaptureRotation()
        await release()
        guard let savedURL else { return nil }
        return RecordingSegment(fileName: savedURL.lastPathComponent, startedAt: startedAt, endedAt: .now)
    }
}
