import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1: rally point scoring, 1 game or best of 3, game winner serves next.
@Suite struct MatchScoringTests {
    @Test func newMatchStartsAtLoveWithFirstServer() throws {
        let match = try Match.singles(firstServer: .b)
        #expect(match.state.score == PerSide(a: 0, b: 0))
        #expect(match.state.servingSide == .b)
        #expect(match.state.status == .inPlay)
        #expect(match.state.gameNumber == 1)
    }

    @Test func everyRallyWinsAPoint() throws {
        var match = try Match.singles()
        try match.play("abba")
        #expect(match.state.score == PerSide(a: 2, b: 2))
        #expect(match.state.rallyCount == 4)
    }

    @Test("The rally winner serves the next rally", arguments: [Side.a, .b])
    func rallyWinnerServesNext(winner: Side) throws {
        var match = try Match.singles(firstServer: .a)
        try match.win(winner)
        #expect(match.state.servingSide == winner)
    }

    @Test func oneGameMatchEndsWhenTheGameIsWon() throws {
        var match = try Match.singles(games: 1)
        try match.win(.b, 21)
        #expect(match.state.status == .matchOver(winner: .b))
        #expect(match.state.winner == .b)
        #expect(match.state.gamesWon == PerSide(a: 0, b: 1))
        #expect(match.state.score == PerSide(a: 0, b: 21))
        #expect(match.state.gameNumber == 1)
    }

    @Test func noRalliesAfterTheMatchIsOver() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 21)
        #expect(throws: ScoringError.matchIsOver) {
            try match.win(.b)
        }
        #expect(match.events.count == 21)
    }

    @Test func bestOfThreeStartsANewGameAfterTheFirst() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        #expect(match.state.status == .inPlay)
        #expect(match.state.gameNumber == 2)
        #expect(match.state.score == PerSide(a: 0, b: 0))
        #expect(match.state.gamesWon == PerSide(a: 1, b: 0))
        #expect(match.state.completedGames == [.init(score: PerSide(a: 21, b: 0), winner: .a)])
    }

    @Test func bestOfThreeEndsAtTwoGamesToNil() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.win(.a, 21)
        #expect(match.state.status == .matchOver(winner: .a))
        #expect(match.state.gameNumber == 2)
    }

    @Test func bestOfThreeGoesToAThirdGameAtOneAll() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        try match.win(.b, 21)
        #expect(match.state.gameNumber == 3)
        #expect(match.state.gamesWon == PerSide(a: 1, b: 1))
        try match.win(.b, 21)
        #expect(match.state.status == .matchOver(winner: .b))
        #expect(match.state.gamesWon == PerSide(a: 1, b: 2))
    }

    @Test func gameWinnerServesFirstInTheNextGame() throws {
        var match = try Match.singles(games: 3, firstServer: .a)
        // B wins game 1 after A won the last rally before B's run.
        try match.win(.b, 20)
        try match.win(.a)
        try match.win(.b)
        #expect(match.state.gameNumber == 2)
        #expect(match.state.servingSide == .b)
    }

    @Test func deuceGameCountsAsOneGame() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 20)
        try match.win(.b, 20)
        try match.play("abab")
        #expect(match.state.score == PerSide(a: 22, b: 22))
        try match.win(.a, 2)
        #expect(match.state.completedGames.last == .init(score: PerSide(a: 24, b: 22), winner: .a))
    }

    @Test func capEndsTheGameAtThirty() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 20)
        try match.win(.b, 20)
        try match.play(String(repeating: "ab", count: 9))
        #expect(match.state.score == PerSide(a: 29, b: 29))
        try match.win(.b)
        #expect(match.state.status == .matchOver(winner: .b))
        #expect(match.state.score == PerSide(a: 29, b: 30))
    }
}
