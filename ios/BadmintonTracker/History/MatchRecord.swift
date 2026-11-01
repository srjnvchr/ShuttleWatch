import Foundation
import SwiftData
import ScoringKit

/// A saved match (FR-09). The match itself is stored as ScoringKit's setup and event list,
/// so the score, server, and rally log can always be rebuilt from it.
/// The other fields are copies for showing the history list quickly.
@Model
final class MatchRecord {
    var startedAt: Date
    var updatedAt: Date
    var isFinished: Bool
    /// For example: "Priya vs Sam".
    var title: String
    /// For example: "Priya win, 21-15" or "In progress, 5-3".
    var result: String
    var matchData: Data
    var namesData: Data
    var eventDates: [Date]
    /// JSON of the match's MatchLabels: recordings and rally start taps.
    var labelsData: Data = Data()

    @MainActor
    init(model: ScoringViewModel, startedAt: Date = .now) {
        self.startedAt = startedAt
        updatedAt = startedAt
        isFinished = false
        title = ""
        result = ""
        matchData = Data()
        namesData = Data()
        eventDates = []
        update(from: model)
    }

    @MainActor
    func update(from model: ScoringViewModel) {
        updatedAt = model.eventDates.last ?? startedAt
        isFinished = model.isOver
        title = "\(model.name(of: .a)) vs \(model.name(of: .b))"
        result = Self.result(for: model)
        eventDates = model.eventDates
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(model.match) {
            matchData = data
        }
        if let data = try? encoder.encode(model.names) {
            namesData = data
        }
        if let data = try? encoder.encode(model.labels) {
            labelsData = data
        }
    }

    /// Rebuilds the match, replaying every event through the rules. Nil if it cannot be read.
    @MainActor
    func makeViewModel() -> ScoringViewModel? {
        let decoder = JSONDecoder()
        guard
            let match = try? decoder.decode(Match.self, from: matchData),
            let names = try? decoder.decode(PlayerNames.self, from: namesData)
        else { return nil }
        return ScoringViewModel(match: match, names: names, eventDates: eventDates, labels: labels)
    }

    /// Nil for matches saved before labels existed.
    var labels: MatchLabels? {
        try? JSONDecoder().decode(MatchLabels.self, from: labelsData)
    }

    @MainActor
    private static func result(for model: ScoringViewModel) -> String {
        if let title = model.resultTitle {
            let summary = model.completedGamesSummary
            return summary.isEmpty ? title : "\(title), \(summary)"
        }
        let score = model.state.score
        return "In progress, \(score.a)-\(score.b)"
    }
}
