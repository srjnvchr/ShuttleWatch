/// Something that happened in a match. The match is stored as a list of these,
/// and the score is worked out from them.
public enum MatchEvent: Hashable, Sendable, Codable {
    /// A rally ended and this side won the point.
    case rallyWon(by: Side)
}

public enum ScoringError: Error, Equatable {
    /// The match has a winner, so nothing more can be recorded.
    case matchIsOver
    /// Doubles needs a server and receiver before the game's first rally.
    case gameSetupNeeded
}
