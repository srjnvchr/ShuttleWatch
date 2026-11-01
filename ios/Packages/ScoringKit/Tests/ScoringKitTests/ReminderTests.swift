import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1 Reminders: intervals and end changes are skippable reminders.
/// Ends change between games only, never during a game.
@Suite struct ReminderTests {
    @Test func intervalReminderWhenTheLeaderFirstReachesTheIntervalPoint() throws {
        var match = try Match.singles()
        try match.win(.a, 10)
        #expect(match.state.reminders.isEmpty)
        try match.win(.a)
        #expect(match.state.reminders == [.interval])
    }

    @Test func intervalReminderLastsOnlyForThatRally() throws {
        var match = try Match.singles()
        try match.win(.a, 11)
        try match.win(.b)
        #expect(match.state.reminders.isEmpty)
    }

    @Test func noIntervalReminderWhenTheTrailingSideCatchesUp() throws {
        var match = try Match.singles()
        try match.win(.a, 11)
        try match.win(.b, 10)
        try match.win(.b)
        #expect(match.state.score == PerSide(a: 11, b: 11))
        #expect(match.state.reminders.isEmpty)
    }

    @Test func intervalReminderWorksForEitherSide() throws {
        var match = try Match.singles()
        try match.play("ab")
        try match.win(.b, 10)
        #expect(match.state.score == PerSide(a: 1, b: 11))
        #expect(match.state.reminders == [.interval])
    }

    @Test func intervalPointComesFromTheFormat() throws {
        var match = Match(setup: MatchSetup(
            kind: .singles,
            format: try MatchFormat(pointsPerGame: 15, pointCap: 17, gamesPerMatch: 1)
        ))
        try match.win(.a, 8)
        #expect(match.state.reminders == [.interval])
    }

    @Test func skippingTheIntervalDoesNotBlockScoring() throws {
        var match = try Match.singles()
        try match.win(.a, 11)
        try match.win(.a)
        #expect(match.state.score == PerSide(a: 12, b: 0))
    }

    @Test func betweenGamesRemindsAboutIntervalAndEnds() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        #expect(match.state.isBetweenGames)
        #expect(match.state.reminders == [.interval, .changeEnds])
    }

    @Test func oneGameMatchHasNoBreakBetweenGames() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 21)
        #expect(!match.state.isBetweenGames)
        #expect(match.state.reminders.isEmpty)
    }

    @Test func changingEndsSwapsTheSideAtTheNearEnd() throws {
        var match = try Match.singles(games: 3)
        #expect(match.state.sideAtNearEnd == .a)
        try match.win(.a, 21)
        try match.record(.changeOfEnds(taken: true))
        #expect(match.state.sideAtNearEnd == .b)
        #expect(match.state.reminders == [.interval])
    }

    @Test func skippingTheEndChangeIsRecorded() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.record(.changeOfEnds(taken: false))
        #expect(match.state.sideAtNearEnd == .a)
        #expect(match.events.last == .changeOfEnds(taken: false))
        #expect(match.state.reminders == [.interval])
    }

    @Test func nextGameCanStartWithoutAnswering() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.win(.b)
        #expect(match.state.score == PerSide(a: 0, b: 1))
        #expect(match.state.sideAtNearEnd == .a)
        #expect(match.state.reminders.isEmpty)
    }

    @Test func endsChangeAgainInTheNextBreak() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.record(.changeOfEnds(taken: true))
        try match.win(.b, 21)
        #expect(match.state.reminders == [.interval, .changeEnds])
        try match.record(.changeOfEnds(taken: true))
        #expect(match.state.sideAtNearEnd == .a)
    }

    @Test func noChangeOfEndsDuringAGame() throws {
        var match = try Match.singles(games: 3)
        #expect(throws: ScoringError.changeOfEndsNotAllowed) {
            try match.record(.changeOfEnds(taken: true))
        }
        try match.win(.a, 5)
        #expect(throws: ScoringError.changeOfEndsNotAllowed) {
            try match.record(.changeOfEnds(taken: true))
        }
    }

    @Test func onlyOneChangeOfEndsPerBreak() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.record(.changeOfEnds(taken: true))
        #expect(throws: ScoringError.changeOfEndsNotAllowed) {
            try match.record(.changeOfEnds(taken: true))
        }
    }

    @Test func noChangeOfEndsAfterTheMatch() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 21)
        #expect(throws: ScoringError.matchIsOver) {
            try match.record(.changeOfEnds(taken: true))
        }
    }

    @Test func noMidGameEndChangeEvenInTheLastGame() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.win(.b, 21)
        try match.win(.a, 11)
        #expect(match.state.gameNumber == 3)
        #expect(match.state.reminders == [.interval])
        #expect(match.state.sideAtNearEnd == .a)
    }

    @Test func doublesCanChangeEndsBeforeOrAfterGameSetup() throws {
        let a1 = Player(side: .a, slot: .first)
        let b1 = Player(side: .b, slot: .first)
        var match = Match(setup: MatchSetup(kind: .doubles, format: try MatchFormat.standard.with(gamesPerMatch: 3)))
        try match.record(.gameStarted(server: a1, receiver: b1))
        try match.win(.a, 21)
        try match.record(.gameStarted(server: a1, receiver: b1))
        #expect(match.state.isBetweenGames)
        try match.record(.changeOfEnds(taken: true))
        #expect(match.state.sideAtNearEnd == .b)
    }

    @Test func undoRestoresEndsAndTheReminder() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.record(.changeOfEnds(taken: true))
        match.undo()
        #expect(match.state.sideAtNearEnd == .a)
        #expect(match.state.reminders == [.interval, .changeEnds])
    }
}
