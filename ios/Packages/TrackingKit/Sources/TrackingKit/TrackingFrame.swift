import CoreGraphics

// All points are 0 to 1 across the image, with the origin at the top left.

/// A player's floor halo.
public struct PlayerMark: Hashable, Sendable, Codable {
    /// Stays the same while the same player is followed from frame to frame.
    public let id: Int
    /// Where the halo sits: at the player's feet, or the take-off spot during a jump.
    public let center: CGPoint
    /// The player's height, as a fraction of the image height. Sizes the halo.
    public let size: CGFloat
    /// True while the halo is held in place because the player seems to be in the air.
    public let isHeld: Bool

    public init(id: Int, center: CGPoint, size: CGFloat, isHeld: Bool) {
        self.id = id
        self.center = center
        self.size = size
        self.isHeld = isHeld
    }
}

/// One frame's worth of tracking, ready to draw. Visual only (FR-27): it never scores.
public struct TrackingFrame: Sendable, Equatable, Codable {
    public var players: [PlayerMark] = []
    public var shuttle: CGPoint?
    /// Recent shuttle positions, oldest first.
    public var trail: [CGPoint] = []
    /// Image width divided by height, to line points up with the picture.
    public var imageAspect: CGFloat = 16.0 / 9.0

    public init(players: [PlayerMark] = [], shuttle: CGPoint? = nil, trail: [CGPoint] = [], imageAspect: CGFloat = 16.0 / 9.0) {
        self.players = players
        self.shuttle = shuttle
        self.trail = trail
        self.imageAspect = imageAspect
    }
}

/// One person found by body pose in one frame.
public struct BodySighting: Hashable, Sendable, Codable {
    /// Midpoint between the ankles, or the one visible ankle.
    public let feet: CGPoint
    /// Ankles to head, as a fraction of the image height.
    public let size: CGFloat

    public init(feet: CGPoint, size: CGFloat) {
        self.feet = feet
        self.size = size
    }
}

/// One possible shuttle position from trajectory detection in one frame.
public struct ShuttleCandidate: Hashable, Sendable, Codable {
    public let point: CGPoint
    public let confidence: Float

    public init(point: CGPoint, confidence: Float) {
        self.point = point
        self.confidence = confidence
    }
}
