import CoreGraphics
import Foundation

/// Keeps the shuttle's recent positions for the circle and trail.
/// Pure logic with no Vision, so it can be tested with made-up candidates.
public struct ShuttleTrail: Sendable {
    /// How many positions the trail keeps (about a third of a second at 30 a second).
    static let length = 10
    /// Trajectory detection gives a confidence from 0 to 1. Weaker candidates are ignored.
    static let minimumConfidence: Float = 0.9
    /// More candidates than this in one frame means noise, such as a moving camera.
    static let noiseLimit = 8
    /// A new point joins the trail only if it is this close to the last one.
    static let joinDistance: CGFloat = 0.12
    /// The circle shows once this many joined points agree.
    static let pointsToShow = 3
    /// The trail clears when the shuttle has not been seen for this long.
    static let fadeAfter: TimeInterval = 0.5

    public private(set) var trail: [CGPoint] = []
    private var lastSeen: TimeInterval?
    private var seenThisFrame = false

    public init() {}

    public mutating func reset() {
        trail = []
        lastSeen = nil
        seenThisFrame = false
    }

    /// The shuttle's position this frame, once the trail is long enough to trust.
    public var current: CGPoint? {
        seenThisFrame && trail.count >= Self.pointsToShow ? trail.last : nil
    }

    public mutating func update(with candidates: [ShuttleCandidate], at time: TimeInterval) {
        seenThisFrame = false
        let usable = candidates.count > Self.noiseLimit ? [] : candidates.filter { $0.confidence >= Self.minimumConfidence }

        if let lastSeen, time - lastSeen > Self.fadeAfter {
            trail = []
        }
        guard !usable.isEmpty else { return }

        if let last = trail.last {
            // Prefer the candidate that continues the trail over a stronger one elsewhere.
            let nearest = usable.min { Self.distance($0.point, last) < Self.distance($1.point, last) }
            if let nearest, Self.distance(nearest.point, last) < Self.joinDistance {
                add(nearest.point, at: time)
                return
            }
        }
        // Nothing continues the trail: start a new one from the strongest candidate.
        if let strongest = usable.max(by: { $0.confidence < $1.confidence }) {
            trail = []
            add(strongest.point, at: time)
        }
    }

    private mutating func add(_ point: CGPoint, at time: TimeInterval) {
        trail.append(point)
        if trail.count > Self.length {
            trail.removeFirst(trail.count - Self.length)
        }
        lastSeen = time
        seenThisFrame = true
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
