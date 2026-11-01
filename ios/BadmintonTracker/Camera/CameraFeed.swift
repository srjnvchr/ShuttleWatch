import AVFoundation
import Observation

/// The live back camera preview for FR-29. View only: nothing is recorded or saved.
@Observable
final class CameraFeed {
    enum Status: Equatable {
        case idle
        case running
        /// No back camera, for example in the simulator.
        case unavailable
        /// The user said no to camera access. It can be changed in Settings.
        case denied
    }

    private(set) var status = Status.idle
    let session = AVCaptureSession()
    private(set) var device: AVCaptureDevice?
    private var isConfigured = false

    func start() async {
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
        status = .running
    }

    func stop() async {
        guard status == .running else { return }
        await Self.run(session, start: false)
        status = .idle
    }

    private func configure(with device: AVCaptureDevice) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return false
        }
        session.addInput(input)
        isConfigured = true
        return true
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
}
