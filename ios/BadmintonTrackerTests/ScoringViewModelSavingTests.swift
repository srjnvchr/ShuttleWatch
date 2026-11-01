import Foundation
import Testing
import ScoringKit
@testable import BadmintonTracker

@MainActor
struct ScoringViewModelSavingTests {
    /// A clock that moves forward one second each time it is read.
    final class TestClock {
        var current = Date(timeIntervalSince1970: 1_000)
        func tick() -> Date {
            current += 1
            return current
        }
    }

    private func singles(games: Int = 1, clock: TestClock = TestClock()) throws -> ScoringViewModel {
        let setup = MatchSetup(kind: .singles, format: try MatchFormat.standard.with(gamesPerMatch: games))
        var names = PlayerNames()
        names[.singles(.a)] = "Priya"
        names[.singles(.b)] = "Sam"
        return ScoringViewModel(setup: setup, names: names, now: clock.tick)
    }

    @Test func everyEventGetsATime() throws {
        let model = try singles()
        model.rallyWon(by: .a)
        model.rallyWon(by: .b)
        #expect(model.eventDates == [Date(timeIntervalSince1970: 1_001), Date(timeIntervalSince1970: 1_002)])
    }

    @Test func undoRemovesTheLastTime() throws {
        let model = try singles()
        model.rallyWon(by: .a)
        model.rallyWon(by: .b)
        model.undo()
        #expect(model.eventDates.count == 1)
    }

    @Test func changesAreReportedButRejectedActionsAreNot() throws {
        let model = try singles()
        var changes = 0
        model.onChange = { changes += 1 }
        model.rallyWon(by: .a)
        model.undo()
        model.undo()
        model.changeOfEnds(taken: true)
        #expect(changes == 2)
        #expect(model.eventDates.isEmpty)
    }

    @Test func endingEarlyGoesToTheLeader() throws {
        let model = try singles()
        model.rallyWon(by: .a)
        model.endMatchEarly(winner: .b)
        #expect(!model.isOver)
        model.endMatchEarly(winner: .a)
        #expect(model.isOver)
        #expect(model.resultTitle == "Priya win (ended early)")
        #expect(model.completedGamesSummary == "1-0")
    }

    @Test func levelScoreEndsWithTheChosenWinner() throws {
        let model = try singles()
        #expect(model.state.leader == nil)
        model.endMatchEarly(winner: .b)
        #expect(model.resultTitle == "Sam win (ended early)")
        #expect(model.completedGamesSummary == "")
    }

    @Test func summaryIncludesTheUnfinishedGame() throws {
        let model = try singles(games: 3)
        for _ in 0..<21 { model.rallyWon(by: .a) }
        model.rallyWon(by: .b)
        model.endMatchEarly(winner: .a)
        #expect(model.completedGamesSummary == "21-0, 0-1")
    }

    @Test func finishedMatchTitleHasNoEarlyNote() throws {
        let model = try singles()
        for _ in 0..<21 { model.rallyWon(by: .b) }
        #expect(model.resultTitle == "Sam win")
    }

    @Test func reopenedMatchKeepsItsTimesAndPadsMissingOnes() throws {
        var match = Match(setup: MatchSetup(kind: .singles))
        try match.record(.rallyWon(by: .a))
        try match.record(.rallyWon(by: .a))
        let first = Date(timeIntervalSince1970: 50)
        let model = ScoringViewModel(match: match, names: PlayerNames(), eventDates: [first])
        #expect(model.eventDates == [first, first])
        #expect(model.state.score == PerSide(a: 2, b: 0))
    }
}
