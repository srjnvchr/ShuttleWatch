import Testing
@testable import ScoringKit

/// ROADMAP.md 6.1 Doubles: service rotation, diagonal receiver, server and receiver chosen per game.
@Suite struct DoublesServiceTests {
    // Side A is players A1 and A2, side B is B1 and B2.
    let a1 = Player(side: .a, slot: .first)
    let a2 = Player(side: .a, slot: .second)
    let b1 = Player(side: .b, slot: .first)
    let b2 = Player(side: .b, slot: .second)

    private func doubles(games: Int = 1, firstServer: Side = .a) throws -> Match {
        Match(setup: MatchSetup(
            kind: .doubles,
            format: try MatchFormat.standard.with(gamesPerMatch: games),
            firstServingSide: firstServer
        ))
    }

    /// A doubles match where A1 serves to B1 in game 1.
    private func started() throws -> Match {
        var match = try doubles()
        try match.record(.gameStarted(server: a1, receiver: b1))
        return match
    }

    private func expectServe(
        _ match: Match, _ server: Player, from court: ServiceCourt, to receiver: Player,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(match.state.server == server, sourceLocation: sourceLocation)
        #expect(match.state.serviceCourt == court, sourceLocation: sourceLocation)
        #expect(match.state.receiver == receiver, sourceLocation: sourceLocation)
    }

    @Test func doublesWaitsForServerAndReceiverBeforeTheFirstRally() throws {
        var match = try doubles()
        #expect(match.state.status == .awaitingGameSetup)
        #expect(match.state.server == nil)
        #expect(throws: ScoringError.gameSetupNeeded) {
            try match.win(.a)
        }
    }

    @Test func firstServerAndReceiverStartInTheirRightCourts() throws {
        let match = try started()
        #expect(match.state.status == .inPlay)
        expectServe(match, a1, from: .right, to: b1)
        #expect(match.state.player(of: .a, in: .left) == a2)
        #expect(match.state.player(of: .b, in: .left) == b2)
    }

    @Test func eitherPlayerCanBeChosenToServeOrReceive() throws {
        var match = try doubles()
        try match.record(.gameStarted(server: a2, receiver: b2))
        expectServe(match, a2, from: .right, to: b2)
    }

    /// The worked example of doubles service: each rally checks server, court, and receiver.
    @Test func serviceRotationFollowsTheBWFExample() throws {
        var match = try started()

        // A wins on their own serve: A1 and A2 swap, A1 serves again from the left.
        try match.win(.a)
        expectServe(match, a1, from: .left, to: b2)

        // B wins the rally and gains the serve. Nobody moves. B's score is 1, so the left court serves.
        try match.win(.b)
        expectServe(match, b2, from: .left, to: a1)

        // B wins on their own serve: B1 and B2 swap, B2 serves again from the right.
        try match.win(.b)
        expectServe(match, b2, from: .right, to: a2)

        // A regains the serve at 2-2. A2 is in A's right court.
        try match.win(.a)
        expectServe(match, a2, from: .right, to: b2)

        // A wins on their own serve: A2 serves again, now from the left.
        try match.win(.a)
        expectServe(match, a2, from: .left, to: b1)
        #expect(match.state.score == PerSide(a: 3, b: 2))
    }

    @Test func receivingSideDoesNotChangeCourtsWhenItWinsTheServe() throws {
        var match = try started()
        try match.win(.b)
        #expect(match.state.player(of: .b, in: .right) == b1)
        #expect(match.state.player(of: .a, in: .right) == a1)
    }

    @Test func receiverIsAlwaysDiagonallyOpposite() throws {
        var match = try started()
        for winner in "abbaabbbaaab" {
            try match.win(winner == "a" ? .a : .b)
            let court = try #require(match.state.serviceCourt)
            #expect(match.state.server == match.state.player(of: match.state.servingSide, in: court))
            #expect(match.state.receiver == match.state.player(of: match.state.servingSide.opponent, in: court))
        }
    }

    @Test func nextGameWaitsForANewServerFromTheWinningSide() throws {
        var match = try doubles(games: 3)
        try match.record(.gameStarted(server: a1, receiver: b1))
        try match.win(.b, 21)
        #expect(match.state.gameNumber == 2)
        #expect(match.state.status == .awaitingGameSetup)
        #expect(match.state.servingSide == .b)

        try match.record(.gameStarted(server: b2, receiver: a2))
        expectServe(match, b2, from: .right, to: a2)
    }

    @Test func gameSetupMustUseTheSideDueToServe() throws {
        var match = try doubles(firstServer: .a)
        #expect(throws: ScoringError.wrongServingSide) {
            try match.record(.gameStarted(server: b1, receiver: a1))
        }
        #expect(throws: ScoringError.receiverOnServingSide) {
            try match.record(.gameStarted(server: a1, receiver: a2))
        }
        #expect(match.events.isEmpty)
    }

    @Test func gameSetupIsOnlyAllowedBeforeAGame() throws {
        var match = try started()
        #expect(throws: ScoringError.gameSetupNotExpected) {
            try match.record(.gameStarted(server: a1, receiver: b1))
        }
    }

    @Test func singlesDoesNotTakeGameSetup() throws {
        var match = try Match.singles()
        #expect(throws: ScoringError.gameSetupNotExpected) {
            try match.record(.gameStarted(server: .singles(.a), receiver: .singles(.b)))
        }
    }

    @Test func undoingGameSetupWaitsForItAgain() throws {
        var match = try started()
        match.undo()
        #expect(match.state.status == .awaitingGameSetup)
        #expect(match.state.server == nil)
    }

    @Test func undoRestoresDoublesPositions() throws {
        var match = try started()
        try match.play("aab")
        match.undo()
        expectServe(match, a1, from: .right, to: b1)
        #expect(match.state.score == PerSide(a: 2, b: 0))
    }
}
