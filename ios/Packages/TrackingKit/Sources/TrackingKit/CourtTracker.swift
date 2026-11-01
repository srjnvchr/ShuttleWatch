import CoreGraphics
import CoreMedia
import CoreVideo
import Vision

/// What Vision found in one frame, before any following or smoothing.
public struct FrameAnalysis: Sendable, Codable {
    public let sightings: [BodySighting]
    public let candidates: [ShuttleCandidate]
    public let imageAspect: CGFloat
}

/// Runs Apple's Vision requests on video frames and turns the results into a TrackingFrame.
/// Players: body pose gives the ankles, and the halo sits between them.
/// Shuttle: Apple's trajectory detection, as a trial until the trained model is ready.
///
/// Not thread-safe: use one instance from one place, such as an actor.
public final class CourtTracker {
    private let sequence = VNSequenceRequestHandler()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private var trajectoryRequest = CourtTracker.makeTrajectoryRequest()
    public private(set) var players = PlayerTracker()
    public private(set) var shuttle = ShuttleTrail()

    public init() {}

    public func reset() {
        players.reset()
        shuttle.reset()
        trajectoryRequest = Self.makeTrajectoryRequest()
    }

    /// Analyses one frame. Frames must arrive in time order, because trajectories span frames.
    public func process(_ sampleBuffer: CMSampleBuffer) -> (frame: TrackingFrame, analysis: FrameAnalysis)? {
        guard let analysis = analyze(sampleBuffer) else { return nil }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let marks = players.update(with: analysis.sightings, at: time)
        shuttle.update(with: analysis.candidates, at: time)
        let frame = TrackingFrame(
            players: marks,
            shuttle: shuttle.current,
            trail: shuttle.trail,
            imageAspect: analysis.imageAspect
        )
        return (frame, analysis)
    }

    /// Why requests failed, counted by message. For diagnosing; the app ignores it.
    public private(set) var failures: [String: Int] = [:]

    private func analyze(_ sampleBuffer: CMSampleBuffer) -> FrameAnalysis? {
        // Run separately, so a failed trajectory request never costs the frame's body pose.
        var bodyOK = true
        do {
            try sequence.perform([bodyRequest], on: sampleBuffer, orientation: .up)
        } catch {
            bodyOK = false
            failures["body: \(error.localizedDescription)", default: 0] += 1
        }
        var trajectoryOK = true
        do {
            try sequence.perform([trajectoryRequest], on: sampleBuffer, orientation: .up)
        } catch {
            trajectoryOK = false
            failures["trajectory: \(error.localizedDescription)", default: 0] += 1
        }
        guard bodyOK || trajectoryOK else { return nil }
        var aspect: CGFloat = 16.0 / 9.0
        if let image = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let width = CGFloat(CVPixelBufferGetWidth(image))
            let height = CGFloat(CVPixelBufferGetHeight(image))
            if height > 0 { aspect = width / height }
        }
        let sightings = bodyOK ? (bodyRequest.results ?? []).compactMap(Self.sighting(from:)) : []
        let candidates = !trajectoryOK ? [] : (trajectoryRequest.results ?? []).compactMap { observation -> ShuttleCandidate? in
            guard let latest = observation.detectedPoints.last else { return nil }
            return ShuttleCandidate(
                point: CGPoint(x: latest.location.x, y: 1 - latest.location.y),
                confidence: observation.confidence
            )
        }
        return FrameAnalysis(sightings: sightings, candidates: candidates, imageAspect: aspect)
    }

    /// The midpoint between the ankles, or the one visible ankle, plus the player's height.
    private static func sighting(from observation: VNHumanBodyPoseObservation) -> BodySighting? {
        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let found = try? observation.recognizedPoint(joint), found.confidence > 0.3 else { return nil }
            // Vision puts the origin at the bottom left. Flip to top left.
            return CGPoint(x: found.location.x, y: 1 - found.location.y)
        }

        let ankles = [point(.leftAnkle), point(.rightAnkle)].compactMap { $0 }
        guard !ankles.isEmpty else { return nil }
        let feet = CGPoint(
            x: ankles.map(\.x).reduce(0, +) / CGFloat(ankles.count),
            y: ankles.map(\.y).reduce(0, +) / CGFloat(ankles.count)
        )
        guard let top = point(.nose) ?? point(.neck) else { return nil }
        return BodySighting(feet: feet, size: max(feet.y - top.y, 0.02))
    }

    private static func makeTrajectoryRequest() -> VNDetectTrajectoriesRequest {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 6)
        // A shuttle is tiny in a full-court view. Ignore anything bigger than a hand.
        request.objectMinimumNormalizedRadius = 0.001
        request.objectMaximumNormalizedRadius = 0.02
        return request
    }
}
