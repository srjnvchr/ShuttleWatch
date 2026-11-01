import AVFoundation
import CoreMedia

/// Receives every camera frame on the capture queue. It writes frames to the recording,
/// and hands some frames to the tracker. Both jobs run off the main thread.
///
/// The actor runs on the same serial queue that AVFoundation delivers frames on,
/// so frame callbacks can use its state directly without hopping.
actor FrameProcessor {
    enum RecordingError: Error {
        case alreadyRecording
        case cannotCreateWriter
    }

    nonisolated let queue = DispatchSerialQueue(label: "BadmintonTracker.frames", qos: .userInitiated)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let tracker: Tracker
    private var isTrackingEnabled = false
    private var isTrackerBusy = false
    private var frameCount = 0

    private var pendingURL: URL?
    private var pendingStart: CheckedContinuation<Date, any Error>?
    private var writer: AVAssetWriter?
    private var receiver: AVAssetWriterInput.SampleBufferReceiver?

    init(tracker: Tracker) {
        self.tracker = tracker
    }

    func setTracking(_ enabled: Bool) {
        isTrackingEnabled = enabled
        if !enabled {
            Task { await tracker.reset() }
        }
    }

    /// Asks for recording to begin with the next frame. Returns the wall-clock time of that
    /// first frame, which is time zero for the rally labels.
    func startRecording(to url: URL) async throws -> Date {
        guard writer == nil, pendingStart == nil else { throw RecordingError.alreadyRecording }
        return try await withCheckedThrowingContinuation { continuation in
            pendingURL = url
            pendingStart = continuation
        }
    }

    /// Finishes the file. Returns its URL, or nil if nothing was recorded.
    func stopRecording() async -> URL? {
        if let pendingStart {
            pendingStart.resume(throwing: CancellationError())
            self.pendingStart = nil
            pendingURL = nil
        }
        guard let writer, let receiver else { return nil }
        self.writer = nil
        self.receiver = nil
        receiver.finish()
        let url = writer.outputURL
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        return writer.status == .completed ? url : nil
    }

    /// Called for every frame, on this actor's queue.
    func process(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        beginRecordingIfRequested(with: sampleBuffer)
        if let receiver {
            // The writer takes ownership of the frames it is given, but the tracker reads this
            // frame too. That is safe: camera frames are never changed after capture, and both
            // only read. This opts the one hand-over out of Swift's ownership check.
            nonisolated(unsafe) let shared = sampleBuffer
            // A full writer refuses the frame rather than waiting, so recording never stalls capture.
            _ = try? receiver.appendImmediately(CMReadySampleBuffer(unsafeBuffer: shared))
        }
        // Track every second frame (30 a second). The tracker skips frames while it is busy,
        // so slow analysis never delays the recording.
        if isTrackingEnabled && !isTrackerBusy && frameCount.isMultiple(of: 2) {
            isTrackerBusy = true
            let frame = SendableSampleBuffer(sampleBuffer)
            Task {
                await tracker.analyze(frame)
                trackerDidFinish()
            }
        }
    }

    private func trackerDidFinish() {
        isTrackerBusy = false
    }

    private func beginRecordingIfRequested(with sampleBuffer: CMSampleBuffer) {
        guard let url = pendingURL, let continuation = pendingStart else { return }
        pendingURL = nil
        pendingStart = nil
        do {
            continuation.resume(returning: try beginWriting(to: url, firstFrame: sampleBuffer))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func beginWriting(to url: URL, firstFrame: CMSampleBuffer) throws -> Date {
        guard
            let format = CMSampleBufferGetFormatDescription(firstFrame),
            let writer = try? AVAssetWriter(outputURL: url, fileType: .mov)
        else { throw RecordingError.cannotCreateWriter }

        let size = CMVideoFormatDescriptionGetDimensions(format)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ])
        guard writer.canAdd(input) else { throw RecordingError.cannotCreateWriter }
        let receiver = writer.inputReceiver(for: input)

        let startTime = CMSampleBufferGetPresentationTimeStamp(firstFrame)
        try writer.start()
        writer.startSession(atSourceTime: startTime)
        self.writer = writer
        self.receiver = receiver

        // Frame times use the host clock. Turn the first frame's time into a wall-clock date,
        // so rally taps (stored as dates) can be placed on the video's timeline.
        let ageOfFrame = CMClockGetTime(CMClockGetHostTimeClock()).seconds - startTime.seconds
        return Date.now.addingTimeInterval(-ageOfFrame)
    }
}

/// Feeds camera frames to the processor. AVFoundation calls it on the processor's own queue.
nonisolated final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    let processor: FrameProcessor

    init(processor: FrameProcessor) {
        self.processor = processor
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Safe: the delegate is registered with the processor's queue, which is its executor,
        // and frames are only read after capture.
        let frame = SendableSampleBuffer(sampleBuffer)
        processor.assumeIsolated { $0.process(frame.buffer) }
    }
}

/// Carries a camera frame to the tracker. Frames are only read after capture, never changed.
nonisolated struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer

    init(_ buffer: CMSampleBuffer) {
        self.buffer = buffer
    }
}
