import Foundation
import Observation
import ScoringKit

/// Drives the scoring screen (FR-04). All rules live in ScoringKit.
/// This only forwards taps to the match and turns its state into display text.
@Observable
final class ScoringViewModel {
    private(set) var match: Match
    let names: PlayerNames
    /// When each event in `match.events` was recorded, in the same order (FR-11 labels).
    private(set) var eventDates: [Date]
    /// Called after every change, so the match can be saved.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Reminders the players have dismissed. Cleared whenever the match changes.
    private var dismissedReminders: Set<MatchState.Reminder> = []
    @ObservationIgnored private let now: () -> Date

    init(setup: MatchSetup, names: PlayerNames, now: @escaping () -> Date = Date.init) {
        match = Match(setup: setup)
        self.names = names
        eventDates = []
        self.now = now
    }

    /// Reopens a saved match. Dates are padded or trimmed to match the events.
    init(match: Match, names: PlayerNames, eventDates: [Date], now: @escaping () -> Date = Date.init) {
        self.match = match
        self.names = names
        let known = Array(eventDates.prefix(match.events.count))
        let fallback = known.last ?? now()
        self.eventDates = known + Array(repeating: fallback, count: match.events.count - known.count)
        self.now = now
    }

    var state: MatchState { match.state }
    var kind: MatchKind { match.setup.kind }
    var canUndo: Bool { match.canUndo }
    var canScore: Bool { state.status == .inPlay }
    var needsGameSetup: Bool { state.status == .awaitingGameSetup }
    var isOver: Bool { state.winner != nil }

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

    /// Ends the match now. The leader wins. When level, `winner` is the players' choice.
    func endMatchEarly(winner: Side) {
        record(.matchEndedEarly(winner: winner))
    }

    func undo() {
        guard match.undo() != nil else { return }
        eventDates.removeLast()
        dismissedReminders = []
        onChange?()
    }

    func dismiss(_ reminder: MatchState.Reminder) {
        dismissedReminders.insert(reminder)
    }

    private func record(_ event: MatchEvent) {
        // The screen only offers actions the rules allow. If a stale tap slips
        // through, ScoringKit rejects it and the match stays as it was.
        do {
            try match.record(event)
        } catch {
            return
        }
        eventDates.append(now())
        dismissedReminders = []
        onChange?()
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

    /// Every game played, including an unfinished one when the match ended early.
    var gameScores: [PerSide<Int>] {
        var scores = state.completedGames.map(\.score)
        if state.endedEarly && state.score != PerSide(a: 0, b: 0) {
            scores.append(state.score)
        }
        return scores
    }

    /// For example: "21-15, 18-21". Uses A's score first.
    var completedGamesSummary: String {
        gameScores.map { "\($0.a)-\($0.b)" }.joined(separator: ", ")
    }

    /// For example: "Priya win" or "Priya win (ended early)".
    var resultTitle: String? {
        guard let winner = state.winner else { return nil }
        return "\(name(of: winner)) win" + (state.endedEarly ? " (ended early)" : "")
    }
}
