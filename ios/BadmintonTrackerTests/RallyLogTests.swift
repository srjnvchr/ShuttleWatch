import Foundation
import Testing
import ScoringKit
@testable import BadmintonTracker

@MainActor
struct RallyLogTests {
    @Test func describesEachRallyWithScoreAndServer() throws {
        var names = PlayerNames()
        names[.singles(.a)] = "Priya"
        names[.singles(.b)] = "Sam"
        let model = ScoringViewModel(setup: MatchSetup(kind: .singles), names: names)
        model.rallyWon(by: .a)
        model.rallyWon(by: .b)

        let entries = RallyLog.entries(for: model)
        #expect(entries.map(\.title) == ["Rally 1: point to Priya", "Rally 2: point to Sam"])
        #expect(entries[0].detail == "Game 1, 1-0, Priya served")
        #expect(entries[1].detail == "Game 1, 1-1, Priya served")
        #expect(entries.map(\.time) == model.eventDates)
    }

    @Test func gameEndingRallyShowsTheFinalScore() throws {
        let model = ScoringViewModel(
            setup: MatchSetup(kind: .singles, format: try MatchFormat.standard.with(gamesPerMatch: 3)),
            names: PlayerNames()
        )
        for _ in 0..<21 { model.rallyWon(by: .b) }
        model.changeOfEnds(taken: false)

        let entries = RallyLog.entries(for: model)
        #expect(entries[20].detail == "Game 1, 0-21, Side B served, game over")
        #expect(entries[21].title == "Skipped changing ends")
        #expect(entries[21].detail == "Before game 2")
    }

    @Test func doublesSetupAndEarlyEndAppearInTheLog() throws {
        let model = ScoringViewModel(setup: MatchSetup(kind: .doubles), names: PlayerNames())
        model.startGame(server: Player(side: .a, slot: .second), receiver: Player(side: .b, slot: .first))
        model.endMatchEarly(winner: .b)

        let entries = RallyLog.entries(for: model)
        #expect(entries.map(\.title) == ["Game 1 starts", "Match ended early"])
        #expect(entries[0].detail == "A2 serves to B1")
        #expect(entries[1].detail == "B1 & B2 win")
    }
}
