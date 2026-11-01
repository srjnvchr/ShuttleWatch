import SwiftUI
import ScoringKit

/// A skippable reminder. Scoring carries on whether or not it is answered.
struct ReminderBanner: View {
    let reminder: MatchState.Reminder
    let model: ScoringViewModel

    var body: some View {
        HStack {
            switch reminder {
            case .interval:
                Label("Interval", systemImage: "pause.circle")
                Spacer()
                Button("Dismiss") { model.dismiss(.interval) }
            case .changeEnds:
                Label("Change ends?", systemImage: "arrow.left.arrow.right")
                Spacer()
                Button("Changed") { model.changeOfEnds(taken: true) }
                    .buttonStyle(.borderedProminent)
                Button("Skip") { model.changeOfEnds(taken: false) }
            }
        }
        .font(.headline)
        .buttonStyle(.bordered)
        .padding(12)
        .background(.yellow.opacity(0.25), in: .rect(cornerRadius: 12))
    }
}
