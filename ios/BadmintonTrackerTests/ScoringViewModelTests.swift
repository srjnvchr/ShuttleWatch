import Testing
import ScoringKit
@testable import BadmintonTracker

@MainActor
struct ScoringViewModelTests {
    let a1 = Player(side: .a, slot: .first)
    let a2 = Player(side: .a, slot: .second)
    let b1 = Player(side: .b, slot: .first)
    let b2 = Player(side: .b, slot: .second)

    private func singles(games: Int = 1) throws -> ScoringViewModel {
        var form = MatchSetupForm()
        form.kind = .singles
        form.gamesPerMatch = games
        form.names[.singles(.a)] = "Priya"
        form.names[.singles(.b)] = "Sam"
        return try #require(form.makeViewModel())
    }

    private func doubles(games: Int = 1) throws -> ScoringViewModel {
        var form = MatchSetupForm()
        form.kind = .doubles
        form.gamesPerMatch = games
        return try #require(form.makeViewModel())
    }

    @Test func tapAwardsThePointStraightAway() throws {
        let model = try singles()
        model.rallyWon(by: .b)
        #expect(model.state.score == PerSide(a: 0, b: 1))
    }

    @Test func serveDescriptionUsesNamesAndCourt() throws {
        let model = try singles()
        #expect(model.serveDescription == "Priya serves from the right to Sam")
        model.rallyWon(by: .b)
        #expect(model.serveDescription == "Sam serves from the left to Priya")
    }

    @Test func undoGoesBackOneRally() throws {
        let model = try singles()
        model.rallyWon(by: .a)
        model.rallyWon(by: .b)
        model.undo()
        #expect(model.state.score == PerSide(a: 1, b: 0))
        #expect(model.canUndo)
    }

    @Test func doublesAsksForGameSetupFirst() throws {
        let model = try doubles()
        #expect(model.needsGameSetup)
        #expect(!model.canScore)
        model.rallyWon(by: .a)
        #expect(model.state.rallyCount == 0)

        model.startGame(server: a2, receiver: b1)
        #expect(model.canScore)
        #expect(model.serveDescription == "A2 serves from the right to B1")
    }

    @Test func invalidActionsLeaveTheMatchUnchanged() throws {
        let model = try singles()
        model.changeOfEnds(taken: true)
        #expect(model.match.events.isEmpty)
    }

    @Test func intervalReminderCanBeDismissed() throws {
        let model = try singles()
        for _ in 0..<11 { model.rallyWon(by: .a) }
        #expect(model.visibleReminders == [.interval])
        model.dismiss(.interval)
        #expect(model.visibleReminders.isEmpty)
    }

    @Test func betweenGamesShowsBothReminders() throws {
        let model = try singles(games: 3)
        for _ in 0..<21 { model.rallyWon(by: .a) }
        #expect(model.visibleReminders == [.interval, .changeEnds])
        model.changeOfEnds(taken: true)
        #expect(model.visibleReminders == [.interval])
        #expect(model.state.sideAtNearEnd == .b)
    }

    @Test func undoBringsBackADismissedReminder() throws {
        let model = try singles(games: 3)
        for _ in 0..<21 { model.rallyWon(by: .a) }
        model.changeOfEnds(taken: false)
        model.undo()
        #expect(model.visibleReminders == [.interval, .changeEnds])
    }

    @Test func labelsAndSummary() throws {
        let model = try singles(games: 3)
        #expect(model.gameLabel == "Game 1 of 3")
        for _ in 0..<21 { model.rallyWon(by: .b) }
        #expect(model.gameLabel == "Game 2 of 3")
        #expect(model.completedGamesSummary == "0-21")
    }
}

@MainActor
struct PlayerNamesTests {
    @Test func emptyNamesFallBackToDefaults() {
        var names = PlayerNames()
        names[.singles(.a)] = "   "
        #expect(names.name(of: .singles(.a), kind: .singles) == "Side A")
        #expect(names.name(of: Player(side: .b, slot: .second), kind: .doubles) == "B2")
    }

    @Test func namesAreTrimmedAndJoinedForDoubles() {
        var names = PlayerNames()
        names[Player(side: .a, slot: .first)] = " Priya "
        names[Player(side: .a, slot: .second)] = "Ana"
        #expect(names.name(of: .a, kind: .doubles) == "Priya & Ana")
    }
}

@MainActor
struct MatchSetupFormTests {
    @Test func defaultsToOneGameOfDoublesTo21() throws {
        let form = MatchSetupForm()
        let format = try #require(form.format)
        #expect(form.kind == .doubles)
        #expect(format == .standard)
    }

    @Test func asksForTwoOrFourNames() {
        var form = MatchSetupForm()
        form.kind = .singles
        #expect(form.players.count == 2)
        form.kind = .doubles
        #expect(form.players.count == 4)
    }

    @Test func capBelowPointsCannotStart() {
        var form = MatchSetupForm()
        form.pointsPerGame = 21
        form.pointCap = 20
        #expect(!form.canStart)
        #expect(form.makeViewModel() == nil)
    }
}
