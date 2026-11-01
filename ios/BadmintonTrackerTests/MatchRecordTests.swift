import Foundation
import SwiftData
import Testing
import ScoringKit
@testable import BadmintonTracker

/// FR-09: matches are saved after every change and can be reopened exactly.
@MainActor
struct MatchRecordTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: MatchRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    private func singles(games: Int = 1) throws -> ScoringViewModel {
        let setup = MatchSetup(kind: .singles, format: try MatchFormat.standard.with(gamesPerMatch: games))
        var names = PlayerNames()
        names[.singles(.a)] = "Priya"
        names[.singles(.b)] = "Sam"
        return ScoringViewModel(setup: setup, names: names)
    }

    @Test func newRecordDescribesTheMatch() throws {
        let model = try singles()
        let record = MatchRecord(model: model)
        #expect(record.title == "Priya vs Sam")
        #expect(record.result == "In progress, 0-0")
        #expect(!record.isFinished)
    }

    @Test func reopenedMatchHasTheSameStateAndTimes() throws {
        let model = try singles(games: 3)
        let record = MatchRecord(model: model)
        context.insert(record)
        for _ in 0..<21 { model.rallyWon(by: .a) }
        model.changeOfEnds(taken: true)
        model.rallyWon(by: .b)
        record.update(from: model)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<MatchRecord>()).first)
        let reopened = try #require(saved.makeViewModel())
        #expect(reopened.match == model.match)
        #expect(reopened.eventDates == model.eventDates)
        #expect(reopened.name(of: .a) == "Priya")
        #expect(reopened.state.sideAtNearEnd == .b)
        #expect(saved.result == "In progress, 0-1")
    }

    @Test func finishedMatchIsMarkedWithItsResult() throws {
        let model = try singles()
        let record = MatchRecord(model: model)
        for _ in 0..<21 { model.rallyWon(by: .b) }
        record.update(from: model)
        #expect(record.isFinished)
        #expect(record.result == "Sam win, 0-21")
    }

    @Test func earlyEndIsSavedAsComplete() throws {
        let model = try singles()
        let record = MatchRecord(model: model)
        model.rallyWon(by: .a)
        model.endMatchEarly(winner: .a)
        record.update(from: model)
        #expect(record.isFinished)
        #expect(record.result == "Priya win (ended early), 1-0")
    }

    @Test func undoAfterTheEndMarksItUnfinishedAgain() throws {
        let model = try singles()
        let record = MatchRecord(model: model)
        model.endMatchEarly(winner: .a)
        record.update(from: model)
        model.undo()
        record.update(from: model)
        #expect(!record.isFinished)
    }

    @Test func unreadableDataDoesNotCrash() throws {
        let record = MatchRecord(model: try singles())
        record.matchData = Data("not json".utf8)
        #expect(record.makeViewModel() == nil)
    }
}
