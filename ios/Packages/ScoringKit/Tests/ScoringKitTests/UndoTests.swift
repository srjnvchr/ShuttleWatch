import Foundation
import Testing
@testable import ScoringKit

/// FR-06: undo, back to the start of the match.
@Suite struct UndoTests {
    @Test func undoRemovesTheLastRally() throws {
        var match = try Match.singles(firstServer: .a)
        try match.play("aab")
        let removed = match.undo()
        #expect(removed == .rallyWon(by: .b))
        #expect(match.state.score == PerSide(a: 2, b: 0))
        #expect(match.state.servingSide == .a)
        #expect(match.state.serviceCourt == .right)
    }

    @Test func undoAllTheWayBackMatchesANewMatch() throws {
        let fresh = try Match.singles(games: 3, firstServer: .b)
        var match = fresh
        try match.play("abbaabab")
        while match.canUndo {
            match.undo()
        }
        #expect(match == fresh)
    }

    @Test func undoAtTheStartDoesNothing() throws {
        var match = try Match.singles()
        #expect(match.undo() == nil)
        #expect(!match.canUndo)
    }

    @Test func undoAcrossAGameBoundaryRestoresThePreviousGame() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 20)
        try match.win(.b, 5)
        try match.win(.a)
        #expect(match.state.gameNumber == 2)
        match.undo()
        #expect(match.state.gameNumber == 1)
        #expect(match.state.score == PerSide(a: 20, b: 5))
        #expect(match.state.servingSide == .b)
        #expect(match.state.completedGames.isEmpty)
    }

    @Test func undoAfterTheMatchEndsReopensIt() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 21)
        match.undo()
        #expect(match.state.status == .inPlay)
        #expect(match.state.score == PerSide(a: 20, b: 0))
        try match.win(.b)
        #expect(match.state.score == PerSide(a: 20, b: 1))
    }

    @Test func savedMatchLoadsWithTheSameState() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.play("bba")
        let data = try JSONEncoder().encode(match)
        let loaded = try JSONDecoder().decode(Match.self, from: data)
        #expect(loaded == match)
        #expect(loaded.state.score == PerSide(a: 1, b: 2))
    }

    @Test func loadingRejectsEventsTheRulesDoNotAllow() throws {
        let setup = MatchSetup(kind: .singles)
        let tooMany = Array(repeating: MatchEvent.rallyWon(by: .a), count: 22)
        #expect(throws: ScoringError.matchIsOver) {
            try Match(setup: setup, events: tooMany)
        }
    }
}
