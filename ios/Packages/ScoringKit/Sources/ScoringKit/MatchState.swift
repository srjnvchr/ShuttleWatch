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

    /// Prompts for the players. They are reminders only: skipping one never blocks scoring.
    public enum Reminder: Hashable, Sendable {
        case interval
        case changeEnds
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
    /// The side at the end nearest the camera.
    public private(set) var sideAtNearEnd: Side
    /// True when the players stopped the match before a side won it.
    public private(set) var endedEarly = false
    /// True only right after the rally where the leader first reached the interval point.
    private var lastRallyReachedInterval = false
    /// Whether a change of ends was already recorded in the current break between games.
    private var endsDecidedThisBreak = false

    public init(setup: MatchSetup) {
        self.setup = setup
        servingSide = setup.firstServingSide
        sideAtNearEnd = setup.sideAtNearEnd
        status = setup.kind == .doubles ? .awaitingGameSetup : .inPlay
    }

    /// Between two games of the same match, before the next game's first rally.
    public var isBetweenGames: Bool {
        guard !completedGames.isEmpty, winner == nil else { return false }
        return score == PerSide(a: 0, b: 0)
    }

    /// What the app should remind the players about right now.
    public var reminders: Set<Reminder> {
        if lastRallyReachedInterval {
            return [.interval]
        }
        guard isBetweenGames else { return [] }
        return endsDecidedThisBreak ? [.interval] : [.interval, .changeEnds]
    }

    public var format: MatchFormat { setup.format }

    public var gamesWon: PerSide<Int> {
        var won = PerSide(a: 0, b: 0)
        for game in completedGames {
            won[game.winner] += 1
        }
        return won
    }

    /// The game being played, counting from 1. After the match ends, the last game played.
    public var gameNumber: Int {
        guard case .matchOver = status else { return completedGames.count + 1 }
        // Ending early mid-game leaves that game unfinished, but it still counts as played.
        let unfinishedGame = endedEarly && (score != PerSide(a: 0, b: 0) || completedGames.isEmpty)
        return completedGames.count + (unfinishedGame ? 1 : 0)
    }

    /// The side ahead: more games won, or if games are level, more points in the current game.
    /// Nil when both are level.
    public var leader: Side? {
        let games = gamesWon
        if games.a != games.b {
            return games.a > games.b ? .a : .b
        }
        if score.a != score.b {
            return score.a > score.b ? .a : .b
        }
        return nil
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
        case .changeOfEnds(let taken):
            try applyChangeOfEnds(taken: taken)
        case .matchEndedEarly(let winner):
            try applyEarlyEnd(winner: winner)
        }
    }

    private mutating func applyEarlyEnd(winner: Side) throws(ScoringError) {
        if self.winner != nil { throw .matchIsOver }
        if let leader, leader != winner { throw .winnerMustBeLeader }
        status = .matchOver(winner: winner)
        endedEarly = true
        lastRallyReachedInterval = false
    }

    private mutating func applyChangeOfEnds(taken: Bool) throws(ScoringError) {
        if winner != nil { throw .matchIsOver }
        guard isBetweenGames, !endsDecidedThisBreak else { throw .changeOfEndsNotAllowed }
        if taken {
            sideAtNearEnd = sideAtNearEnd.opponent
        }
        endsDecidedThisBreak = true
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

        guard let gameWinner = format.gameWinner(of: score) else {
            // Scores rise one at a time, so the leader first reaches the interval point
            // exactly when the rally winner hits it while the other side is still below.
            lastRallyReachedInterval = score[side] == format.intervalPoint
                && score[side.opponent] < format.intervalPoint
            return
        }
        lastRallyReachedInterval = false
        endsDecidedThisBreak = false
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
