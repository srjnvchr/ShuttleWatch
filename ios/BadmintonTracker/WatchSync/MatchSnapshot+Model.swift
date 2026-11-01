import Foundation
import ScoringKit
import WatchLink

extension MatchSnapshot {
    /// What the Watch should show for the iPhone's current match.
    @MainActor
    init(model: ScoringViewModel, handledIntentIDs: [UUID], sentAt: Date) {
        let state = model.state
        let status: Status = switch state.status {
        case .matchOver: .matchOver
        case .awaitingGameSetup: .awaitingGameSetup
        case .inPlay: .inPlay
        }
        // Reminders are sent as they stand. Each device dismisses its own.
        let reminders: [Reminder] = [MatchState.Reminder.interval, .changeEnds]
            .filter { state.reminders.contains($0) }
            .map { $0 == .interval ? .interval : .changeEnds }

        self.init(
            status: status,
            names: PerSide(a: model.name(of: .a), b: model.name(of: .b)),
            score: state.score,
            gamesWon: state.gamesWon,
            gamesPerMatch: model.match.setup.format.gamesPerMatch,
            gameNumber: state.gameNumber,
            servingSide: model.canScore ? state.servingSide : nil,
            serveLine: Self.serveLine(for: model),
            reminders: reminders,
            resultTitle: model.resultTitle,
            canUndo: model.canUndo,
            rallyCount: state.rallyCount,
            handledIntentIDs: handledIntentIDs,
            sentAt: sentAt
        )
    }

    /// Shorter than the iPhone's line, to fit the Watch: "Priya serves from the right".
    @MainActor
    private static func serveLine(for model: ScoringViewModel) -> String? {
        guard let server = model.state.server, let court = model.state.serviceCourt else { return nil }
        return "\(model.name(of: server)) serves from the \(court.rawValue)"
    }
}
