import Foundation
import Testing
import ScoringKit
@testable import WatchLink

/// FR-07: the iPhone and Watch stay in sync, the iPhone decides, and Watch taps queue.
@Suite struct WatchLinkTests {
    private func snapshot(sentAt seconds: TimeInterval, handled: [UUID] = []) -> MatchSnapshot {
        MatchSnapshot(
            status: .inPlay,
            names: PerSide(a: "Priya", b: "Sam"),
            score: PerSide(a: 3, b: 1),
            gamesWon: PerSide(a: 0, b: 0),
            gamesPerMatch: 1,
            gameNumber: 1,
            servingSide: .a,
            serveLine: "Priya serves from the left",
            reminders: [.interval],
            resultTitle: nil,
            canUndo: true,
            rallyCount: 4,
            awaitingServe: true,
            isRecording: true,
            handledIntentIDs: handled,
            sentAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func intentsSurviveEncoding() throws {
        for intent in [WatchIntent.point(.a), .point(.b), .undo, .serve] {
            let message = IntentMessage(intent: intent)
            let data = try WatchMessage.encode(message)
            #expect(try WatchMessage.decode(IntentMessage.self, from: data) == message)
        }
    }

    @Test func snapshotSurvivesEncoding() throws {
        let original = snapshot(sentAt: 10, handled: [UUID()])
        let data = try WatchMessage.encode(original)
        #expect(try WatchMessage.decode(MatchSnapshot.self, from: data) == original)
    }

    @Test func inboxAcceptsEachIntentOnce() {
        var inbox = IntentInbox()
        let id = UUID()
        let first = inbox.accept(id)
        let repeated = inbox.accept(id)
        let other = inbox.accept(UUID())
        #expect(first)
        #expect(!repeated)
        #expect(other)
    }

    @Test func inboxForgetsTheOldestPastItsLimit() {
        var inbox = IntentInbox(limit: 2)
        let first = UUID()
        _ = inbox.accept(first)
        _ = inbox.accept(UUID())
        _ = inbox.accept(UUID())
        #expect(inbox.recent.count == 2)
        #expect(!inbox.recent.contains(first))
    }

    @Test func pendingTapsClearOnceHandled() {
        var pending = PendingIntents()
        let first = IntentMessage(intent: .point(.a))
        let second = IntentMessage(intent: .point(.b))
        pending.add(first)
        pending.add(second)
        pending.confirm(from: snapshot(sentAt: 1, handled: [first.id]))
        #expect(pending.messages == [second])
    }

    @Test func olderSnapshotsNeverReplaceNewerOnes() {
        let newer = snapshot(sentAt: 20)
        #expect(newer.isNewer(than: nil))
        #expect(newer.isNewer(than: snapshot(sentAt: 10)))
        #expect(!snapshot(sentAt: 10).isNewer(than: newer))
    }

    @Test func noMatchSnapshotHasNothingToPlay() {
        let empty = MatchSnapshot.noMatch(handledIntentIDs: [], sentAt: .now)
        #expect(empty.status == .noMatch)
        #expect(empty.servingSide == nil)
        #expect(!empty.canUndo)
    }
}
