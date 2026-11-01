/// Where a match stands, worked out by applying its events in order.
public struct MatchState: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        /// Doubles is waiting for the server and receiver of the next game.
        case awaitingGameSetup
        case inPlay
        case matchOver(winner: Side)
    }

    public struct GameResult: Hashable, Sendable, Codable {
        public let score: PerSide<Int>
        public let winner: Side
    }

    public let setup: MatchSetup
    /// The current game's score. After the match ends, the final game's score.
    public private(set) var score = PerSide(a: 0, b: 0)
    public private(set) var completedGames: [GameResult] = []
    public private(set) var servingSide: Side
    public private(set) var status: Status
    /// How many rallies have been played in the whole match.
    public private(set) var rallyCount = 0

    public init(setup: MatchSetup) {
        self.setup = setup
        servingSide = setup.firstServingSide
        status = setup.kind == .doubles ? .awaitingGameSetup : .inPlay
    }

    public var format: MatchFormat { setup.format }

    public var gamesWon: PerSide<Int> {
        var won = PerSide(a: 0, b: 0)
        for game in completedGames {
            won[game.winner] += 1
        }
        return won
    }

    /// The game being played, counting from 1. After the match ends, the last game.
    public var gameNumber: Int {
        if case .matchOver = status {
            return completedGames.count
        }
        return completedGames.count + 1
    }

    public var winner: Side? {
        if case .matchOver(let winner) = status {
            return winner
        }
        return nil
    }

    /// The player serving the next rally, or nil when no rally can be played.
    public var server: Player? {
        guard status == .inPlay else { return nil }
        return .singles(servingSide)
    }

    /// The player receiving the next rally. Always in the court diagonally opposite the server.
    public var receiver: Player? {
        guard status == .inPlay else { return nil }
        return .singles(servingSide.opponent)
    }

    /// The service court the server stands in, from the serving side's score.
    public var serviceCourt: ServiceCourt? {
        guard status == .inPlay else { return nil }
        return ServiceCourt(forScore: score[servingSide])
    }

    mutating func apply(_ event: MatchEvent) throws(ScoringError) {
        switch event {
        case .rallyWon(let side):
            try applyRally(wonBy: side)
        }
    }

    private mutating func applyRally(wonBy side: Side) throws(ScoringError) {
        switch status {
        case .matchOver: throw .matchIsOver
        case .awaitingGameSetup: throw .gameSetupNeeded
        case .inPlay: break
        }

        rallyCount += 1
        score[side] += 1
        // Rally point scoring: whoever wins the rally serves the next one.
        servingSide = side

        guard let gameWinner = format.gameWinner(of: score) else { return }
        completedGames.append(GameResult(score: score, winner: gameWinner))

        if gamesWon[gameWinner] >= format.gamesToWin {
            status = .matchOver(winner: gameWinner)
            return
        }

        // The winner of a game serves first in the next game.
        score = PerSide(a: 0, b: 0)
        servingSide = gameWinner
        status = setup.kind == .doubles ? .awaitingGameSetup : .inPlay
    }
}
