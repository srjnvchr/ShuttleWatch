import SwiftUI
import ScoringKit

/// FR-04: manual scoring. Tap the half of the side that won the rally.
struct ScoringView: View {
    let model: ScoringViewModel
    let onEndMatch: () -> Void
    @State private var confirmingEnd = false
    @State private var showingCamera = false

    var body: some View {
        Group {
            if showingCamera {
                CameraView(model: model) { showingCamera = false }
            } else {
                scoring
            }
        }
        .sheet(isPresented: Binding(get: { model.needsGameSetup }, set: { _ in })) {
            GameSetupSheet(model: model, onEndMatch: onEndMatch)
        }
        .confirmationDialog("End this match?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End match", role: .destructive, action: onEndMatch)
        } message: {
            Text("The score is not saved yet.")
        }
    }

    private var scoring: some View {
        VStack(spacing: 0) {
            sideButton(.a)
            centerBar
            sideButton(.b)
        }
        .sensoryFeedback(.impact, trigger: model.state.rallyCount)
        .overlay {
            if let winner = model.state.winner {
                matchOver(winner: winner)
            }
        }
    }

    private func sideButton(_ side: Side) -> some View {
        let serving = model.canScore && model.state.servingSide == side
        return Button {
            model.rallyWon(by: side)
        } label: {
            VStack(spacing: 8) {
                Text(model.name(of: side))
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(model.state.score[side])")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if model.match.setup.format.gamesPerMatch > 1 {
                    gamesWon(side)
                }
                Label(serving ? "Serving" : "Receiving", systemImage: serving ? "circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(model.canScore ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .background(Color.accentColor.opacity(serving ? 0.22 : 0.06))
        }
        .buttonStyle(.plain)
        .disabled(!model.canScore)
        .accessibilityLabel("Point to \(model.name(of: side))")
    }

    private func gamesWon(_ side: Side) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<model.match.setup.format.gamesToWin, id: \.self) { index in
                Image(systemName: index < model.state.gamesWon[side] ? "circle.fill" : "circle")
            }
        }
        .font(.caption)
        .accessibilityLabel("\(model.state.gamesWon[side]) games won")
    }

    private var centerBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text(model.gameLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Camera", systemImage: "video") { showingCamera = true }
                    .labelStyle(.iconOnly)
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .disabled(!model.canUndo)
                Menu {
                    Button("End match", systemImage: "xmark", role: .destructive) { confirmingEnd = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .buttonStyle(.bordered)

            if let serve = model.serveDescription {
                Text(serve)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }

            ForEach(model.visibleReminders, id: \.self) { reminder in
                ReminderBanner(reminder: reminder, model: model)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func matchOver(winner: Side) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
            Text("\(model.name(of: winner)) win")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(model.completedGamesSummary)
                .font(.title2.monospacedDigit())
            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .buttonStyle(.bordered)
                Button("Camera", systemImage: "video") { showingCamera = true }
                    .buttonStyle(.bordered)
                Button("New match", action: onEndMatch)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
