import SwiftUI
import ScoringKit
import TrackingKit

/// FR-29: the live camera preview with each side's score on top. View only, so stray
/// touches while setting up the tripod never change the score.
/// FR-27: optional player halos and shuttle trail, drawn on screen only.
struct CameraView: View {
    let model: ScoringViewModel
    let onShowScoring: () -> Void
    @Environment(CaptureController.self) private var capture
    @State private var isCalibrating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            preview
            if isCalibrating {
                CalibrationView(
                    existing: capture.calibration,
                    imageAspect: capture.imageAspect,
                    onSave: { capture.calibration = $0; isCalibrating = false },
                    onClear: { capture.calibration = nil; isCalibrating = false },
                    onCancel: { isCalibrating = false }
                )
            } else if capture.isTrackingEnabled, let frame = capture.overlay.frame {
                TrackingOverlayView(frame: frame, calibration: capture.calibration)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .top) {
            if !isCalibrating {
                scoreBar.padding()
            }
        }
        .overlay(alignment: .bottom) {
            if !isCalibrating {
                bottomButtons
            }
        }
        .task { await capture.acquire() }
        .onDisappear {
            Task { await capture.release() }
        }
    }

    private var bottomButtons: some View {
        @Bindable var capture = capture
        return VStack(spacing: 8) {
            HStack {
                Toggle(isOn: $capture.isTrackingEnabled) {
                    Label("Tracking", systemImage: "scope")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(.white)
                Button(capture.calibration == nil ? "Calibrate" : "Recalibrate", systemImage: "square.dashed") {
                    isCalibrating = true
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(capture.status != .running)
            }
            Button("Scoring", systemImage: "rectangle.split.1x2", action: onShowScoring)
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding()
    }

    @ViewBuilder
    private var preview: some View {
        switch capture.status {
        case .running:
            if let device = capture.device {
                CameraPreview(session: capture.session, device: device)
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
            HStack(spacing: 8) {
                if capture.isRecording {
                    Label("REC", systemImage: "record.circle.fill")
                        .foregroundStyle(.red)
                }
                Text(statusLine)
            }
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
