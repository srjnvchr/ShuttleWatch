/// The configurable values of a match (FR-03). Rules: ROADMAP.md section 6.1.
public struct MatchFormat: Hashable, Sendable, Codable {
    public enum Error: Swift.Error, Equatable {
        case pointsPerGameTooLow
        case capBelowPointsPerGame
        case gamesPerMatchNotOdd
    }

    /// A side wins the game on reaching this score with a lead of at least 2.
    public let pointsPerGame: Int
    /// Reaching this score wins the game outright, whatever the lead.
    public let pointCap: Int
    /// Total games a match can last. Must be odd, so there is always a winner.
    public let gamesPerMatch: Int

    /// The default format: one game to 21, capped at 30.
    public static let standard = try! MatchFormat(pointsPerGame: 21, pointCap: 30, gamesPerMatch: 1)

    /// The minimum lead needed to win a game below the cap.
    public static let winningLead = 2

    public init(pointsPerGame: Int, pointCap: Int, gamesPerMatch: Int) throws(Error) {
        guard pointsPerGame >= 1 else { throw .pointsPerGameTooLow }
        guard pointCap >= pointsPerGame else { throw .capBelowPointsPerGame }
        guard gamesPerMatch >= 1, gamesPerMatch % 2 == 1 else { throw .gamesPerMatchNotOdd }
        self.pointsPerGame = pointsPerGame
        self.pointCap = pointCap
        self.gamesPerMatch = gamesPerMatch
    }

    /// The same format with a different number of games.
    public func with(gamesPerMatch: Int) throws(Error) -> MatchFormat {
        try MatchFormat(pointsPerGame: pointsPerGame, pointCap: pointCap, gamesPerMatch: gamesPerMatch)
    }

    /// Games a side must win to take the match: 1 of 1, 2 of 3.
    public var gamesToWin: Int {
        gamesPerMatch / 2 + 1
    }

    /// Half the points per game, rounded up: 11 for 21, 8 for 15.
    public var intervalPoint: Int {
        (pointsPerGame + 1) / 2
    }

    /// The side that has won a game at this score, or nil if it is still going.
    public func gameWinner(of score: PerSide<Int>) -> Side? {
        Side.allCases.first { side in
            let own = score[side]
            let lead = own - score[side.opponent]
            return own >= pointCap || (own >= pointsPerGame && lead >= Self.winningLead)
        }
    }
}
