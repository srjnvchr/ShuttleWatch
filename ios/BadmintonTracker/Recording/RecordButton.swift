import SwiftUI

/// FR-11: starts and stops recording by hand. Shows a red dot and the time while recording.
struct RecordButton: View {
    let model: ScoringViewModel
    @Environment(CaptureController.self) private var capture
    @Environment(WatchSyncService.self) private var watchSync
    @State private var isBusy = false
    @State private var failed = false

    var body: some View {
        Button {
            toggle()
        } label: {
            if let startedAt = capture.recordingStartedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Label {
                        Text(Self.elapsed(from: startedAt, to: context.date))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "record.circle.fill")
                    }
                }
                .foregroundStyle(.red)
            } else {
                Label("Record", systemImage: "record.circle")
                    .labelStyle(.iconOnly)
            }
        }
        .disabled(isBusy)
        .accessibilityLabel(capture.isRecording ? "Stop recording" : "Start recording")
        .alert("Recording could not start", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The camera is not available. Check camera access in Settings.")
        }
    }

    private func toggle() {
        isBusy = true
        Task {
            if capture.isRecording {
                if let segment = await capture.stopRecording() {
                    model.addRecording(segment)
                }
            } else {
                let folder = RecordingStore.folder(named: model.labels.folderName)
                failed = !(await capture.startRecording(in: folder))
            }
            watchSync.push()
            isBusy = false
        }
    }

    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
