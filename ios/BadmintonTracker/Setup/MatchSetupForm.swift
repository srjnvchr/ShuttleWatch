import ScoringKit

/// The choices on the match setup screen (FR-01), kept apart from the view so they can be tested.
struct MatchSetupForm: Hashable {
    var kind: MatchKind = .doubles
    var names = PlayerNames()
    /// 1 game or best of 3. New matches default to 1 game.
    var gamesPerMatch = MatchFormat.standard.gamesPerMatch
    var pointsPerGame = MatchFormat.standard.pointsPerGame
    var pointCap = MatchFormat.standard.pointCap
    var firstServingSide: Side = .a
    var sideAtNearEnd: Side = .a

    static let gameChoices = [1, 3]

    /// The players that need names for the chosen kind.
    var players: [Player] {
        let slots: [Player.Slot] = kind == .singles ? [.first] : [.first, .second]
        return Side.allCases.flatMap { side in slots.map { Player(side: side, slot: $0) } }
    }

    var format: MatchFormat? {
        try? MatchFormat(pointsPerGame: pointsPerGame, pointCap: pointCap, gamesPerMatch: gamesPerMatch)
    }

    var canStart: Bool {
        format != nil
    }

    func makeViewModel() -> ScoringViewModel? {
        guard let format else { return nil }
        let setup = MatchSetup(
            kind: kind,
            format: format,
            firstServingSide: firstServingSide,
            sideAtNearEnd: sideAtNearEnd
        )
        return ScoringViewModel(setup: setup, names: names)
    }
}
