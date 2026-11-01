import ScoringKit
import SwiftUI
import WatchLink

/// FR-05: score from the wrist. Tap the side that won the rally, or undo.
/// Everything else (starting, game setup, end changes, ending) happens on the iPhone.
struct ContentView: View {
    @Environment(WatchSession.self) private var link

    var body: some View {
        if let snapshot = link.snapshot, snapshot.status != .noMatch {
            MatchView(snapshot: snapshot)
        } else {
            ContentUnavailableView(
                "No match",
                systemImage: "iphone",
                description: Text("Start a match on your iPhone.")
            )
        }
    }
}

struct MatchView: View {
    let snapshot: MatchSnapshot
    @Environment(WatchSession.self) private var link
    /// Reminders hidden on this Watch, keyed so they come back for the next one.
    @State private var dismissed: Set<String> = []

    private var canScore: Bool { snapshot.status == .inPlay }

    var body: some View {
        VStack(spacing: 4) {
            sideButton(.a)
            sideButton(.b)
            footer
        }
        .overlay(alignment: .top) {
            if let reminder = visibleReminder {
                reminderBanner(reminder)
            }
        }
        .overlay {
            if let result = snapshot.resultTitle {
                matchOver(result)
            }
        }
    }

    private func sideButton(_ side: Side) -> some View {
        let serving = snapshot.servingSide == side
        return Button {
            link.send(.point(side))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .opacity(serving ? 1 : 0)
                        Text(snapshot.names[side])
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    if snapshot.gamesPerMatch > 1 {
                        Text("Games \(snapshot.gamesWon[side])")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Text("\(snapshot.score[side])")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(serving ? .blue : .gray)
        .disabled(!canScore)
        .accessibilityLabel("Point to \(snapshot.names[side]), \(snapshot.score[side])")
    }

    private var footer: some View {
        HStack {
            Text(statusLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            Button("Undo", systemImage: "arrow.uturn.backward") { link.send(.undo) }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .frame(width: 44)
                .disabled(!snapshot.canUndo && link.pending.count == 0)
        }
    }

    private var statusLine: String {
        if link.pending.count > 0 {
            let taps = link.pending.count == 1 ? "1 tap" : "\(link.pending.count) taps"
            return "\(taps) waiting for iPhone"
        }
        if snapshot.status == .awaitingGameSetup {
            return "Set up game \(snapshot.gameNumber) on iPhone"
        }
        return snapshot.serveLine ?? ""
    }

    private var visibleReminder: MatchSnapshot.Reminder? {
        snapshot.reminders.first { !dismissed.contains(key(for: $0)) }
    }

    private func key(for reminder: MatchSnapshot.Reminder) -> String {
        "\(reminder.rawValue)-\(snapshot.gameNumber)-\(snapshot.rallyCount)"
    }

    private func reminderBanner(_ reminder: MatchSnapshot.Reminder) -> some View {
        Button {
            dismissed.insert(key(for: reminder))
        } label: {
            Label(
                reminder == .interval ? "Interval" : "Change ends?",
                systemImage: reminder == .interval ? "pause.circle" : "arrow.left.arrow.right"
            )
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .tint(.yellow)
        .accessibilityHint("Dismisses the reminder")
    }

    private func matchOver(_ result: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
            Text(result)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(snapshot.score.a)-\(snapshot.score.b)")
                .monospacedDigit()
            Button("Undo", systemImage: "arrow.uturn.backward") { link.send(.undo) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
    }
}
