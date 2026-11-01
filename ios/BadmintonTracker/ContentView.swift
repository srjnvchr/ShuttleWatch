import ScoringKit
import SwiftData
import SwiftUI

/// Shows match setup until a match starts, then the scoring screen.
/// Every change is saved straight away, and an unfinished match reopens on launch.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var scoring: ScoringViewModel?
    @State private var record: MatchRecord?
    @State private var checkedForUnfinished = false

    var body: some View {
        Group {
            if let scoring {
                ScoringView(model: scoring, onEndMatch: closeMatch)
            } else {
                MatchSetupView(onStart: start)
            }
        }
        .task {
            guard !checkedForUnfinished else { return }
            checkedForUnfinished = true
            reopenUnfinishedMatch()
        }
    }

    private func start(_ model: ScoringViewModel) {
        let record = MatchRecord(model: model)
        context.insert(record)
        try? context.save()
        open(model, saving: record)
    }

    private func open(_ model: ScoringViewModel, saving record: MatchRecord) {
        let context = context
        model.onChange = { [weak model] in
            guard let model else { return }
            record.update(from: model)
            try? context.save()
        }
        self.record = record
        scoring = model
    }

    private func closeMatch() {
        // A match closed before anything happened (doubles setup cancelled) is not worth keeping.
        if let record, let scoring, scoring.match.events.isEmpty {
            context.delete(record)
            try? context.save()
        }
        scoring = nil
        record = nil
    }

    private func reopenUnfinishedMatch() {
        var descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first, let model = record.makeViewModel() else {
            return
        }
        open(model, saving: record)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MatchRecord.self, inMemory: true)
}
