import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1 Ending early: the leader wins, games first, then current points.
/// When level, the players choose. The match then counts as complete.
@Suite struct EarlyEndTests {
    @Test func leaderInTheCurrentGameWins() throws {
        var match = try Match.singles()
        try match.play("abaa")
        #expect(match.state.leader == .a)
        try match.record(.matchEndedEarly(winner: .a))
        #expect(match.state.status == .matchOver(winner: .a))
        #expect(match.state.endedEarly)
        #expect(match.state.score == PerSide(a: 3, b: 1))
    }

    @Test func theTrailingSideCannotBeNamedWinner() throws {
        var match = try Match.singles()
        try match.play("aab")
        #expect(throws: ScoringError.winnerMustBeLeader) {
            try match.record(.matchEndedEarly(winner: .b))
        }
        #expect(match.state.winner == nil)
    }

    @Test("When level, either side can be chosen", arguments: [Side.a, .b])
    func levelScoreLetsPlayersChoose(winner: Side) throws {
        var match = try Match.singles()
        try match.play("abab")
        #expect(match.state.leader == nil)
        try match.record(.matchEndedEarly(winner: winner))
        #expect(match.state.winner == winner)
    }

    @Test func endingAtLoveAllLetsPlayersChoose() throws {
        var match = try Match.singles()
        try match.record(.matchEndedEarly(winner: .b))
        #expect(match.state.winner == .b)
        #expect(match.state.gameNumber == 1)
    }

    @Test func gamesWonCountBeforeCurrentPoints() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.play("bbbbbbbbbbaaaaa")
        #expect(match.state.score == PerSide(a: 5, b: 10))
        #expect(match.state.leader == .a)
        #expect(throws: ScoringError.winnerMustBeLeader) {
            try match.record(.matchEndedEarly(winner: .b))
        }
        try match.record(.matchEndedEarly(winner: .a))
        #expect(match.state.gameNumber == 2)
    }

    @Test func levelGamesFallBackToCurrentPoints() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.win(.b, 21)
        try match.play("bba")
        #expect(match.state.leader == .b)
    }

    @Test func endingBetweenGamesUsesGamesWon() throws {
        var match = try Match.singles(games: 3)
        try match.win(.b, 21)
        #expect(match.state.leader == .b)
        try match.record(.matchEndedEarly(winner: .b))
        #expect(match.state.gameNumber == 1)
    }

    @Test func noMoreRalliesOrRemindersAfterEndingEarly() throws {
        var match = try Match.singles()
        try match.win(.a, 11)
        #expect(match.state.reminders == [.interval])
        try match.record(.matchEndedEarly(winner: .a))
        #expect(match.state.reminders.isEmpty)
        #expect(match.state.server == nil)
        #expect(throws: ScoringError.matchIsOver) {
            try match.win(.a)
        }
    }

    @Test func cannotEndAMatchThatIsAlreadyWon() throws {
        var match = try Match.singles()
        try match.win(.a, 21)
        #expect(throws: ScoringError.matchIsOver) {
            try match.record(.matchEndedEarly(winner: .a))
        }
    }

    @Test func doublesCanEndWhileWaitingForGameSetup() throws {
        var match = Match(setup: MatchSetup(kind: .doubles))
        try match.record(.matchEndedEarly(winner: .a))
        #expect(match.state.winner == .a)
    }

    @Test func undoReopensTheMatch() throws {
        var match = try Match.singles()
        try match.play("aa")
        try match.record(.matchEndedEarly(winner: .a))
        match.undo()
        #expect(match.state.status == .inPlay)
        #expect(!match.state.endedEarly)
        try match.win(.b)
        #expect(match.state.score == PerSide(a: 2, b: 1))
    }
}
