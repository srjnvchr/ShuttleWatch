import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1: game to 21, win by 2 from 20-all, cap at 30.
@Suite struct GameScoringTests {
    let format = MatchFormat.standard

    private func score(_ a: Int, _ b: Int) -> PerSide<Int> {
        PerSide(a: a, b: b)
    }

    @Test func standardFormatIsOneGameTo21CappedAt30() {
        #expect(format.pointsPerGame == 21)
        #expect(format.pointCap == 30)
        #expect(format.gamesPerMatch == 1)
    }

    @Test("A game is won at the points per game", arguments: [(21, 0), (21, 19), (0, 21), (19, 21)])
    func gameWonAtPointsPerGame(a: Int, b: Int) {
        let expected: Side = a > b ? .a : .b
        #expect(format.gameWinner(of: score(a, b)) == expected)
    }

    @Test("No winner before the points per game", arguments: [(0, 0), (20, 0), (11, 11), (19, 20)])
    func noWinnerBeforePointsPerGame(a: Int, b: Int) {
        #expect(format.gameWinner(of: score(a, b)) == nil)
    }

    @Test("From 20-all, a side must lead by 2", arguments: [(21, 20), (20, 21), (25, 24), (28, 29)])
    func leadOfOneIsNotEnoughAfterDeuce(a: Int, b: Int) {
        #expect(format.gameWinner(of: score(a, b)) == nil)
    }

    @Test("From 20-all, a lead of 2 wins", arguments: [(22, 20), (20, 22), (26, 24), (27, 29)])
    func leadOfTwoWinsAfterDeuce(a: Int, b: Int) {
        let expected: Side = a > b ? .a : .b
        #expect(format.gameWinner(of: score(a, b)) == expected)
    }

    @Test("At 29-all, the next point wins (cap of 30)", arguments: [(30, 29), (29, 30)])
    func capWinsWithLeadOfOne(a: Int, b: Int) {
        let expected: Side = a > b ? .a : .b
        #expect(format.gameWinner(of: score(a, b)) == expected)
    }

    @Test func otherFormatsUseTheirOwnValues() throws {
        let short = try MatchFormat(pointsPerGame: 15, pointCap: 17, gamesPerMatch: 1)
        #expect(short.gameWinner(of: score(15, 13)) == .a)
        #expect(short.gameWinner(of: score(15, 14)) == nil)
        #expect(short.gameWinner(of: score(17, 16)) == .a)
    }

    @Test func capEqualToPointsMeansNoDeuce() throws {
        let noDeuce = try MatchFormat(pointsPerGame: 11, pointCap: 11, gamesPerMatch: 1)
        #expect(noDeuce.gameWinner(of: score(11, 10)) == .a)
    }

    @Test("Interval point is half the points per game, rounded up", arguments: [(21, 11), (15, 8), (11, 6), (1, 1)])
    func intervalPoint(points: Int, expected: Int) throws {
        let format = try MatchFormat(pointsPerGame: points, pointCap: points, gamesPerMatch: 1)
        #expect(format.intervalPoint == expected)
    }

    @Test("Games to win the match", arguments: [(1, 1), (3, 2), (5, 3)])
    func gamesToWin(games: Int, expected: Int) throws {
        #expect(try format.with(gamesPerMatch: games).gamesToWin == expected)
    }

    @Test func rejectsInvalidFormats() {
        #expect(throws: MatchFormat.Error.pointsPerGameTooLow) {
            try MatchFormat(pointsPerGame: 0, pointCap: 30, gamesPerMatch: 1)
        }
        #expect(throws: MatchFormat.Error.capBelowPointsPerGame) {
            try MatchFormat(pointsPerGame: 21, pointCap: 20, gamesPerMatch: 1)
        }
        #expect(throws: MatchFormat.Error.gamesPerMatchNotOdd) {
            try MatchFormat(pointsPerGame: 21, pointCap: 30, gamesPerMatch: 2)
        }
        #expect(throws: MatchFormat.Error.gamesPerMatchNotOdd) {
            try MatchFormat(pointsPerGame: 21, pointCap: 30, gamesPerMatch: 0)
        }
    }
}
