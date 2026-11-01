import SwiftUI
import ScoringKit

/// FR-29: the live camera preview with each side's score on top. View only, so stray
/// touches while setting up the tripod never change the score.
struct CameraView: View {
    let model: ScoringViewModel
    let onShowScoring: () -> Void
    @State private var feed = CameraFeed()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            preview
        }
        .overlay(alignment: .top) {
            scoreBar.padding()
        }
        .overlay(alignment: .bottom) {
            Button("Scoring", systemImage: "rectangle.split.1x2", action: onShowScoring)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
        }
        .task { await feed.start() }
        .onDisappear {
            Task { await feed.stop() }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch feed.status {
        case .running:
            if let device = feed.device {
                CameraPreview(session: feed.session, device: device)
                    .ignoresSafeArea()
            }
        case .idle:
            ProgressView()
                .tint(.white)
        case .unavailable:
            message("Camera not available", detail: "This device has no back camera.")
        case .denied:
            message("Camera access is off", detail: "Turn it on in Settings, Privacy & Security, Camera.")
        }
    }

    private func message(_ title: String, detail: String) -> some View {
        ContentUnavailableView(title, systemImage: "video.slash", description: Text(detail))
            .foregroundStyle(.white)
    }

    private var scoreBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                sideScore(.a)
                sideScore(.b)
            }
            Text(statusLine)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: .capsule)
        }
        .foregroundStyle(.white)
    }

    private var statusLine: String {
        model.resultTitle ?? model.gameLabel
    }

    private func sideScore(_ side: Side) -> some View {
        let serving = model.canScore && model.state.servingSide == side
        return HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .opacity(serving ? 1 : 0)
                .accessibilityHidden(!serving)
            Text(model.name(of: side))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            if model.match.setup.format.gamesPerMatch > 1 {
                Text("\(model.state.gamesWon[side])")
                    .font(.caption.monospacedDigit())
                    .padding(4)
                    .overlay(Circle().stroke(.white.opacity(0.6)))
                    .accessibilityLabel("\(model.state.gamesWon[side]) games won")
            }
            Text("\(model.state.score[side])")
                .font(.title.bold().monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
