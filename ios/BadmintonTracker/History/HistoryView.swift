import ScoringKit
import SwiftData
import SwiftUI

/// FR-09: every saved match, newest first. Swipe left to delete one.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MatchRecord.startedAt, order: .reverse) private var records: [MatchRecord]

    var body: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    MatchDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.headline)
                        Text(record.result)
                            .font(.subheadline)
                        Text(record.startedAt, format: .dateTime.weekday().day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    // Deleting a match also deletes its videos, which can be several GB.
                    if let labels = records[index].labels {
                        RecordingStore.deleteFolder(named: labels.folderName)
                    }
                    context.delete(records[index])
                }
                try? context.save()
            }
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "No matches yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Matches appear here as soon as you start scoring.")
                )
            }
        }
        .navigationTitle("History")
    }
}

/// One match: its result, games, and the rally-by-rally log with times.
struct MatchDetailView: View {
    let record: MatchRecord

    var body: some View {
        if let model = record.makeViewModel() {
            List {
                Section {
                    LabeledContent("Result", value: model.resultTitle ?? "In progress")
                    if !model.gameScores.isEmpty {
                        LabeledContent("Games", value: model.completedGamesSummary)
                    }
                    LabeledContent("Started") {
                        Text(record.startedAt, format: .dateTime.day().month().year().hour().minute())
                    }
                    LabeledContent("Rallies", value: "\(model.state.rallyCount)")
                    if !model.labels.recordings.isEmpty {
                        LabeledContent("Videos", value: videoSummary(model.labels.recordings))
                    }
                }
                Section("Log") {
                    ForEach(RallyLog.entries(for: model)) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.time, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(record.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView(
                "Can't open this match",
                systemImage: "exclamationmark.triangle",
                description: Text("Its saved data could not be read.")
            )
        }
    }

    /// For example: "2 videos, 14 min".
    private func videoSummary(_ recordings: [RecordingSegment]) -> String {
        let seconds = recordings.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
        let count = recordings.count == 1 ? "1 video" : "\(recordings.count) videos"
        return "\(count), \(Int((seconds / 60).rounded())) min"
    }
}
