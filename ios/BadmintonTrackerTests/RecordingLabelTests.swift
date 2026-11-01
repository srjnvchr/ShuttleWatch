import Foundation
import SwiftData
import Testing
import ScoringKit
import WatchLink
@testable import BadmintonTracker

/// FR-11 and FR-12: rally start marking, recordings, and the labels file.
@MainActor
struct RecordingLabelTests {
    /// A clock that moves forward one second each time it is read, from 1,000 s.
    final class TestClock {
        var current = Date(timeIntervalSince1970: 1_000)
        func tick() -> Date {
            current += 1
            return current
        }
    }

    private func singles(marking: Bool = true, clock: TestClock = TestClock()) -> ScoringViewModel {
        var names = PlayerNames()
        names[.singles(.a)] = "Priya"
        names[.singles(.b)] = "Sam"
        return ScoringViewModel(
            setup: MatchSetup(kind: .singles),
            names: names,
            marksRallyStarts: marking,
            now: clock.tick
        )
    }

    @Test func serveIsNeededOnlyWhenMarkingIsOn() {
        #expect(singles(marking: true).awaitingServe)
        #expect(!singles(marking: false).awaitingServe)
    }

    @Test func serveThenPointStoresTheRallyStart() {
        let model = singles()
        model.markRallyStart()
        #expect(!model.awaitingServe)
        model.rallyWon(by: .a)
        #expect(model.labels.rallyStarts == [0: Date(timeIntervalSince1970: 1_002)])
        #expect(model.awaitingServe)
    }

    @Test func pointsStillCountWithoutAServeTap() {
        let model = singles()
        model.rallyWon(by: .b)
        #expect(model.state.score == PerSide(a: 0, b: 1))
        #expect(model.labels.rallyStarts.isEmpty)
    }

    @Test func undoTakesBackTheServeTapFirst() {
        let model = singles()
        model.rallyWon(by: .a)
        model.markRallyStart()
        model.undo()
        #expect(model.awaitingServe)
        #expect(model.state.score == PerSide(a: 1, b: 0))
    }

    @Test func undoingAPointReturnsToThatRallyInPlay() {
        let model = singles()
        model.markRallyStart()
        let start = model.currentRallyStart
        model.rallyWon(by: .a)
        model.undo()
        #expect(model.state.score == PerSide(a: 0, b: 0))
        #expect(model.currentRallyStart == start)
        #expect(model.labels.rallyStarts.isEmpty)
        model.rallyWon(by: .b)
        #expect(model.labels.rallyStarts[0] == start)
    }

    @Test func folderNameUsesTheMatchTitleAndDate() {
        let date = ISO8601DateFormatter().date(from: "2026-11-01T14:30:00Z")!
        let name = MatchLabels.folderName(title: "Priya vs Sam/Ana", startedAt: date)
        #expect(name.hasPrefix("2026-11-01 "))
        #expect(name.hasSuffix(" Priya vs Sam-Ana"))
    }

    @Test func labelsPlaceRalliesOnTheVideoTimeline() {
        let clock = TestClock()
        let model = singles(clock: clock)
        let videoStart = Date(timeIntervalSince1970: 1_000.5)
        model.markRallyStart()   // 1,002
        model.rallyWon(by: .a)   // 1,003
        model.rallyWon(by: .b)   // 1,004, no serve tap
        model.addRecording(RecordingSegment(fileName: "video-1.mov", startedAt: videoStart, endedAt: clock.current + 10))

        let file = LabelExport.labels(for: model)
        #expect(file.videos.map(\.file) == ["video-1.mov"])
        #expect(file.rallies.count == 2)

        let first = file.rallies[0]
        #expect(first.winner == "a")
        #expect(first.winnerName == "Priya")
        #expect(first.server == "Priya")
        #expect(first.scoreAfter == [1, 0])
        #expect(first.video == 0)
        #expect(first.startSeconds == 1.5)
        #expect(first.endSeconds == 2.5)

        let second = file.rallies[1]
        #expect(second.startedAt == nil)
        #expect(second.startSeconds == nil)
        #expect(second.endSeconds == 3.5)
    }

    @Test func ralliesOutsideAnyVideoHaveNoVideoTimes() {
        let model = singles()
        model.rallyWon(by: .a)
        let file = LabelExport.labels(for: model)
        #expect(file.rallies[0].video == nil)
        #expect(file.rallies[0].endSeconds == nil)
    }

    @Test func labelsAreSavedWithTheMatch() throws {
        let container = try ModelContainer(
            for: MatchRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let model = singles()
        let record = MatchRecord(model: model)
        container.mainContext.insert(record)
        model.markRallyStart()
        model.rallyWon(by: .a)
        model.addRecording(RecordingSegment(fileName: "v.mov", startedAt: .now, endedAt: .now))
        record.update(from: model)

        let reopened = try #require(record.makeViewModel())
        #expect(reopened.labels == model.labels)
        #expect(reopened.labels.marksRallyStarts)
    }

    @Test func watchServeMarksTheRallyStart() {
        let sync = WatchSyncService()
        let model = singles()
        sync.model = model
        #expect(sync.snapshot().awaitingServe)
        sync.handle(IntentMessage(intent: .serve))
        #expect(model.currentRallyStart != nil)
        #expect(!sync.snapshot().awaitingServe)
    }
}
