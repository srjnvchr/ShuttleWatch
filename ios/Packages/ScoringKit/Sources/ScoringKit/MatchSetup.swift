/// Everything decided before the first rally (FR-01).
public struct MatchSetup: Hashable, Sendable, Codable {
    public var kind: MatchKind
    public var format: MatchFormat
    /// The side that serves first in game 1.
    public var firstServingSide: Side
    /// The side that starts at the end nearest the camera.
    public var sideAtNearEnd: Side

    public init(
        kind: MatchKind,
        format: MatchFormat = .standard,
        firstServingSide: Side = .a,
        sideAtNearEnd: Side = .a
    ) {
        self.kind = kind
        self.format = format
        self.firstServingSide = firstServingSide
        self.sideAtNearEnd = sideAtNearEnd
    }
}
