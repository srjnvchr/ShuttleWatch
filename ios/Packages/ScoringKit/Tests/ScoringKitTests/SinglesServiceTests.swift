import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1 Singles: serve from the right court on an even score, left on odd.
@Suite struct SinglesServiceTests {
    @Test func serverStartsInTheRightCourt() throws {
        let match = try Match.singles(firstServer: .a)
        #expect(match.state.server == .singles(.a))
        #expect(match.state.receiver == .singles(.b))
        #expect(match.state.serviceCourt == .right)
    }

    @Test("Court follows the server's own score", arguments: [
        (1, ServiceCourt.left), (2, .right), (3, .left), (10, .right), (11, .left),
    ])
    func courtFollowsServerScore(points: Int, expected: ServiceCourt) throws {
        var match = try Match.singles(firstServer: .a)
        try match.win(.a, points)
        #expect(match.state.server == .singles(.a))
        #expect(match.state.serviceCourt == expected)
    }

    @Test func newServerUsesTheirOwnScoreNotTheOpponents() throws {
        var match = try Match.singles(firstServer: .a)
        try match.win(.a, 3)
        // B wins the rally at 3-0, so B serves at 3-1 from the left (1 is odd).
        try match.win(.b)
        #expect(match.state.server == .singles(.b))
        #expect(match.state.serviceCourt == .left)
        try match.win(.b)
        #expect(match.state.serviceCourt == .right)
    }

    @Test func nextGameStartsFromTheRightCourt() throws {
        var match = try Match.singles(games: 3)
        try match.win(.a, 21)
        #expect(match.state.serviceCourt == .right)
    }

    @Test func noServerOnceTheMatchIsOver() throws {
        var match = try Match.singles(games: 1)
        try match.win(.a, 21)
        #expect(match.state.server == nil)
        #expect(match.state.receiver == nil)
        #expect(match.state.serviceCourt == nil)
    }
}
