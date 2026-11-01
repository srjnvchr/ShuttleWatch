import CoreGraphics
import CoreMedia
import Vision

/// A player's floor halo. Points are 0 to 1 across the image, with the origin at the top left.
nonisolated struct PlayerMark: Hashable, Sendable {
    /// Where the halo sits: between the ankles, or the last grounded spot during a jump.
    let center: CGPoint
    /// The player's height, as a fraction of the image height. Sizes the halo.
    let size: CGFloat
}

/// One frame's worth of tracking, ready to draw. Visual only (FR-27): it never scores.
nonisolated struct TrackingFrame: Sendable {
    var players: [PlayerMark] = []
    var shuttle: CGPoint?
    /// Recent shuttle positions, oldest first.
    var trail: [CGPoint] = []
    /// Image width divided by height, to line points up with the preview.
    var imageAspect: CGFloat = 16.0 / 9.0
}

/// Runs Apple's Vision requests on camera frames.
/// Players: body pose gives the ankles, and the halo sits between them.
/// Shuttle: Apple's trajectory detection, as a trial until the trained model is ready.
actor Tracker {
    private let overlay: TrackingOverlay
    private let sequence = VNSequenceRequestHandler()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private var trajectoryRequest = Tracker.makeTrajectoryRequest()

    private var players: [TrackedPlayer] = []
    private var nextPlayerID = 0
    private var trail: [CGPoint] = []
    private var framesWithoutShuttle = 0

    /// How many shuttle positions the trail keeps (about a third of a second at 30 a second).
    private static let trailLength = 10
    /// Frames a player can go unseen before the halo is removed.
    private static let maxMissedFrames = 15

    init(overlay: TrackingOverlay) {
        self.overlay = overlay
    }

    func reset() {
        players = []
        trail = []
        framesWithoutShuttle = 0
        trajectoryRequest = Self.makeTrajectoryRequest()
        publish(TrackingFrame())
    }

    func analyze(_ frame: SendableSampleBuffer) {
        let buffer = frame.buffer
        guard (try? sequence.perform([bodyRequest, trajectoryRequest], on: buffer, orientation: .up)) != nil else {
            return
        }

        var result = TrackingFrame()
        if let image = CMSampleBufferGetImageBuffer(buffer) {
            let width = CGFloat(CVPixelBufferGetWidth(image))
            let height = CGFloat(CVPixelBufferGetHeight(image))
            if height > 0 { result.imageAspect = width / height }
        }

        updatePlayers(with: bodyRequest.results ?? [])
        result.players = players.map { PlayerMark(center: $0.ground, size: $0.size) }

        updateShuttle(with: trajectoryRequest.results ?? [])
        result.trail = trail
        result.shuttle = framesWithoutShuttle == 0 ? trail.last : nil

        publish(result)
    }

    private func publish(_ frame: TrackingFrame) {
        Task { @MainActor [overlay] in overlay.show(frame) }
    }

    // MARK: Players

    private struct TrackedPlayer {
        let id: Int
        var ground: CGPoint
        var size: CGFloat
        /// Recent ankle heights (larger means lower in the image), to spot jumps.
        var recentFeetY: [CGFloat]
        var missedFrames: Int
    }

    private struct Sighting {
        let feet: CGPoint
        let size: CGFloat
    }

    private func updatePlayers(with observations: [VNHumanBodyPoseObservation]) {
        let sightings = observations.compactMap(Self.sighting(from:))
        var unmatched = Array(sightings.indices)

        for index in players.indices {
            // Pair each known player with the nearest sighting, if it is close enough.
            let nearest = unmatched.min { a, b in
                Self.distance(sightings[a].feet, players[index].ground)
                    < Self.distance(sightings[b].feet, players[index].ground)
            }
            if let nearest, Self.distance(sightings[nearest].feet, players[index].ground) < 0.12 {
                unmatched.removeAll { $0 == nearest }
                Self.update(&players[index], with: sightings[nearest])
            } else {
                players[index].missedFrames += 1
            }
        }
        players.removeAll { $0.missedFrames > Self.maxMissedFrames }

        for index in unmatched {
            let sighting = sightings[index]
            players.append(TrackedPlayer(
                id: nextPlayerID,
                ground: sighting.feet,
                size: sighting.size,
                recentFeetY: [sighting.feet.y],
                missedFrames: 0
            ))
            nextPlayerID += 1
        }
    }

    /// Moves the halo only while the player is on the ground. During a jump the feet rise
    /// well above their recent lowest point, and the halo stays where they took off.
    private static func update(_ player: inout TrackedPlayer, with sighting: Sighting) {
        player.missedFrames = 0
        player.size = player.size * 0.8 + sighting.size * 0.2
        player.recentFeetY.append(sighting.feet.y)
        if player.recentFeetY.count > 30 {
            player.recentFeetY.removeFirst(player.recentFeetY.count - 30)
        }
        let lowestRecent = player.recentFeetY.max() ?? sighting.feet.y
        let isAirborne = lowestRecent - sighting.feet.y > player.size * 0.12
        if !isAirborne {
            player.ground = sighting.feet
        }
    }

    /// The midpoint between the ankles, or the one visible ankle, plus the player's height.
    private static func sighting(from observation: VNHumanBodyPoseObservation) -> Sighting? {
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
        let size = max(feet.y - top.y, 0.02)
        return Sighting(feet: feet, size: size)
    }

    // MARK: Shuttle

    private func updateShuttle(with observations: [VNTrajectoryObservation]) {
        guard
            let best = observations.max(by: { $0.confidence < $1.confidence }),
            let latest = best.detectedPoints.last
        else {
            framesWithoutShuttle += 1
            if framesWithoutShuttle > 15 { trail = [] }
            return
        }
        framesWithoutShuttle = 0
        trail.append(CGPoint(x: latest.location.x, y: 1 - latest.location.y))
        if trail.count > Self.trailLength {
            trail.removeFirst(trail.count - Self.trailLength)
        }
    }

    private static func makeTrajectoryRequest() -> VNDetectTrajectoriesRequest {
        let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 6)
        // A shuttle is tiny in a full-court view. Ignore anything bigger than a hand.
        request.objectMinimumNormalizedRadius = 0.001
        request.objectMaximumNormalizedRadius = 0.02
        return request
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
