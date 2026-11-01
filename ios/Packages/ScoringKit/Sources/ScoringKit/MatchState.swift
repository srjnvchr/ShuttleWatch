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
    /// Doubles: which player of each side stands in their right service court.
    public private(set) var rightCourtSlot = PerSide(a: Player.Slot.first, b: .first)

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

    /// The service court the server stands in, from the serving side's score.
    public var serviceCourt: ServiceCourt? {
        guard status == .inPlay else { return nil }
        return ServiceCourt(forScore: score[servingSide])
    }

    /// The player serving the next rally, or nil when no rally can be played.
    /// Doubles: the serving side's player in the court matching their score.
    public var server: Player? {
        guard let serviceCourt else { return nil }
        return player(of: servingSide, in: serviceCourt)
    }

    /// The player receiving the next rally. Always in the court diagonally opposite the server.
    public var receiver: Player? {
        guard let serviceCourt else { return nil }
        return player(of: servingSide.opponent, in: serviceCourt)
    }

    /// Who stands in a side's right or left service court. Singles has one player per side.
    public func player(of side: Side, in court: ServiceCourt) -> Player {
        guard setup.kind == .doubles else { return .singles(side) }
        let right = Player(side: side, slot: rightCourtSlot[side])
        return court == .right ? right : right.partner
    }

    mutating func apply(_ event: MatchEvent) throws(ScoringError) {
        switch event {
        case .rallyWon(let side):
            try applyRally(wonBy: side)
        case .gameStarted(let server, let receiver):
            try applyGameStart(server: server, receiver: receiver)
        }
    }

    private mutating func applyGameStart(server: Player, receiver: Player) throws(ScoringError) {
        switch status {
        case .matchOver: throw .matchIsOver
        case .inPlay: throw .gameSetupNotExpected
        case .awaitingGameSetup: break
        }
        guard server.side == servingSide else { throw .wrongServingSide }
        guard receiver.side == servingSide.opponent else { throw .receiverOnServingSide }

        // At 0-0 both stand in their right court, diagonally opposite each other.
        rightCourtSlot[server.side] = server.slot
        rightCourtSlot[receiver.side] = receiver.slot
        status = .inPlay
    }

    private mutating func applyRally(wonBy side: Side) throws(ScoringError) {
        switch status {
        case .matchOver: throw .matchIsOver
        case .awaitingGameSetup: throw .gameSetupNeeded
        case .inPlay: break
        }

        rallyCount += 1
        score[side] += 1
        // Doubles: only the serving side changes courts, and only when it wins the rally.
        // The same player then serves again from the other court.
        if setup.kind == .doubles && side == servingSide {
            rightCourtSlot[side] = Player(side: side, slot: rightCourtSlot[side]).partner.slot
        }
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
