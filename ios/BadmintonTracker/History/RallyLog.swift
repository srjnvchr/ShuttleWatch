import Foundation
import ScoringKit

/// One line of a match's log (FR-09): a rally, a game start, an end change, or an early end.
struct RallyLogEntry: Identifiable, Equatable {
    let id: Int
    let time: Date
    let title: String
    let detail: String
}

enum RallyLog {
    /// Replays the match one event at a time, describing each with the state just before and after.
    static func entries(for model: ScoringViewModel) -> [RallyLogEntry] {
        var replay = Match(setup: model.match.setup)
        var entries: [RallyLogEntry] = []
        var rallyNumber = 0

        for (index, event) in model.match.events.enumerated() {
            let before = replay.state
            guard (try? replay.record(event)) != nil else { break }
            let after = replay.state
            let title: String
            let detail: String

            switch event {
            case .rallyWon(let side):
                rallyNumber += 1
                let endedGame = after.completedGames.count > before.completedGames.count
                let score = endedGame ? (after.completedGames.last?.score ?? after.score) : after.score
                title = "Rally \(rallyNumber): point to \(model.name(of: side))"
                var parts = ["Game \(before.gameNumber)", "\(score.a)-\(score.b)"]
                if let server = before.server {
                    parts.append("\(model.name(of: server)) served")
                }
                if endedGame {
                    parts.append("game over")
                }
                detail = parts.joined(separator: ", ")
            case .gameStarted(let server, let receiver):
                title = "Game \(after.gameNumber) starts"
                detail = "\(model.name(of: server)) serves to \(model.name(of: receiver))"
            case .changeOfEnds(let taken):
                title = taken ? "Changed ends" : "Skipped changing ends"
                detail = "Before game \(after.gameNumber)"
            case .matchEndedEarly(let winner):
                title = "Match ended early"
                detail = model.wins(winner)
            }

            entries.append(RallyLogEntry(id: index, time: model.eventDates[index], title: title, detail: detail))
        }
        return entries
    }
}
