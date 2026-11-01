import Foundation
import Testing
import ScoringKit
import WatchLink
@testable import BadmintonTracker

/// FR-05 and FR-07: Watch taps go through the iPhone, which decides and reports back.
@MainActor
struct WatchSyncTests {
    private func singles() -> ScoringViewModel {
        var names = PlayerNames()
        names[.singles(.a)] = "Priya"
        names[.singles(.b)] = "Sam"
        return ScoringViewModel(setup: MatchSetup(kind: .singles), names: names)
    }

    @Test func watchTapAwardsThePointOnTheiPhone() {
        let sync = WatchSyncService()
        let model = singles()
        sync.model = model
        sync.handle(IntentMessage(intent: .point(.b)))
        #expect(model.state.score == PerSide(a: 0, b: 1))
    }

    @Test func aTapDeliveredTwiceCountsOnce() {
        let sync = WatchSyncService()
        let model = singles()
        sync.model = model
        let tap = IntentMessage(intent: .point(.a))
        sync.handle(tap)
        sync.handle(tap)
        #expect(model.state.score == PerSide(a: 1, b: 0))
        #expect(sync.snapshot().handledIntentIDs == [tap.id])
    }

    @Test func watchUndoUndoesOnTheiPhone() {
        let sync = WatchSyncService()
        let model = singles()
        sync.model = model
        model.rallyWon(by: .a)
        sync.handle(IntentMessage(intent: .undo))
        #expect(model.state.score == PerSide(a: 0, b: 0))
    }

    @Test func tapsWithNoMatchOpenAreConfirmedButChangeNothing() {
        let sync = WatchSyncService()
        let tap = IntentMessage(intent: .point(.a))
        sync.handle(tap)
        let snapshot = sync.snapshot()
        #expect(snapshot.status == .noMatch)
        #expect(snapshot.handledIntentIDs == [tap.id])
    }

    @Test func snapshotDescribesTheMatch() {
        let model = singles()
        model.rallyWon(by: .b)
        let snapshot = MatchSnapshot(model: model, handledIntentIDs: [], sentAt: .now)
        #expect(snapshot.status == .inPlay)
        #expect(snapshot.names == PerSide(a: "Priya", b: "Sam"))
        #expect(snapshot.score == PerSide(a: 0, b: 1))
        #expect(snapshot.servingSide == .b)
        #expect(snapshot.serveLine == "Sam serves from the left")
        #expect(snapshot.canUndo)
        #expect(snapshot.rallyCount == 1)
    }

    @Test func doublesBetweenGamesWaitsForTheiPhone() {
        let model = ScoringViewModel(setup: MatchSetup(kind: .doubles), names: PlayerNames())
        let snapshot = MatchSnapshot(model: model, handledIntentIDs: [], sentAt: .now)
        #expect(snapshot.status == .awaitingGameSetup)
        #expect(snapshot.servingSide == nil)
        #expect(snapshot.serveLine == nil)
    }

    @Test func snapshotCarriesRemindersAndResult() {
        let model = singles()
        for _ in 0..<11 { model.rallyWon(by: .a) }
        #expect(MatchSnapshot(model: model, handledIntentIDs: [], sentAt: .now).reminders == [.interval])
        model.endMatchEarly(winner: .a)
        let over = MatchSnapshot(model: model, handledIntentIDs: [], sentAt: .now)
        #expect(over.status == .matchOver)
        #expect(over.resultTitle == "Priya wins (ended early)")
        #expect(over.reminders.isEmpty)
    }
}
