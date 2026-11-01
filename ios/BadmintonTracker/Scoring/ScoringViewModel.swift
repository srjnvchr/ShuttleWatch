import Observation
import ScoringKit

/// Drives the scoring screen (FR-04). All rules live in ScoringKit.
/// This only forwards taps to the match and turns its state into display text.
@Observable
final class ScoringViewModel {
    private(set) var match: Match
    let names: PlayerNames
    /// Reminders the players have dismissed. Cleared whenever the match changes.
    private var dismissedReminders: Set<MatchState.Reminder> = []

    init(setup: MatchSetup, names: PlayerNames) {
        match = Match(setup: setup)
        self.names = names
    }

    var state: MatchState { match.state }
    var kind: MatchKind { match.setup.kind }
    var canUndo: Bool { match.canUndo }
    var canScore: Bool { state.status == .inPlay }
    var needsGameSetup: Bool { state.status == .awaitingGameSetup }

    // MARK: Actions

    func rallyWon(by side: Side) {
        record(.rallyWon(by: side))
    }

    func startGame(server: Player, receiver: Player) {
        record(.gameStarted(server: server, receiver: receiver))
    }

    func changeOfEnds(taken: Bool) {
        record(.changeOfEnds(taken: taken))
    }

    func undo() {
        match.undo()
        dismissedReminders = []
    }

    func dismiss(_ reminder: MatchState.Reminder) {
        dismissedReminders.insert(reminder)
    }

    private func record(_ event: MatchEvent) {
        // The screen only offers actions the rules allow. If a stale tap slips
        // through, ScoringKit rejects it and the match stays as it was.
        do {
            try match.record(event)
            dismissedReminders = []
        } catch {}
    }

    // MARK: Display

    func name(of player: Player) -> String {
        names.name(of: player, kind: kind)
    }

    func name(of side: Side) -> String {
        names.name(of: side, kind: kind)
    }

    /// For example: "Priya serves from the right to Sam".
    var serveDescription: String? {
        guard let server = state.server, let receiver = state.receiver, let court = state.serviceCourt else {
            return nil
        }
        return "\(name(of: server)) serves from the \(court.rawValue) to \(name(of: receiver))"
    }

    var visibleReminders: [MatchState.Reminder] {
        [.interval, .changeEnds].filter { state.reminders.contains($0) && !dismissedReminders.contains($0) }
    }

    var gameLabel: String {
        "Game \(state.gameNumber) of \(match.setup.format.gamesPerMatch)"
    }

    /// For example: "21-15, 18-21". Uses A's score first.
    var completedGamesSummary: String {
        state.completedGames.map { "\($0.score.a)-\($0.score.b)" }.joined(separator: ", ")
    }
}
