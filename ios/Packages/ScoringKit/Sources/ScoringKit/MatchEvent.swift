/// Something that happened in a match. The match is stored as a list of these,
/// and the score is worked out from them.
public enum MatchEvent: Hashable, Sendable, Codable {
    /// A rally ended and this side won the point.
    case rallyWon(by: Side)
    /// Doubles only: who serves and who receives the first rally of a game.
    case gameStarted(server: Player, receiver: Player)
    /// Between games: whether the players changed ends (`true`) or skipped it (`false`).
    case changeOfEnds(taken: Bool)
}

public enum ScoringError: Error, Equatable {
    /// The match has a winner, so nothing more can be recorded.
    case matchIsOver
    /// Doubles needs a server and receiver before the game's first rally.
    case gameSetupNeeded
    /// Game setup is only for doubles, before a game's first rally.
    case gameSetupNotExpected
    /// The server must be on the side due to serve.
    case wrongServingSide
    /// The receiver must be on the other side from the server.
    case receiverOnServingSide
    /// Ends can only change between games, once per break. Never during a game.
    case changeOfEndsNotAllowed
}
