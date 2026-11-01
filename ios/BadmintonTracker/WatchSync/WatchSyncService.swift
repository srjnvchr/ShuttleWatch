import Foundation
import Observation
import ScoringKit
import WatchConnectivity
import WatchLink

/// FR-07: the iPhone side of Watch sync. The iPhone is the single source of truth.
/// The Watch sends taps, this applies them through the same view model as the iPhone's
/// own taps, and sends back a snapshot after every change.
@Observable
final class WatchSyncService: NSObject {
    /// The open match, or nil when none is open.
    var model: ScoringViewModel? {
        didSet { push() }
    }

    /// Whether the iPhone is recording, shown on the Watch. Set by the app.
    @ObservationIgnored var isRecording: () -> Bool = { false }
    @ObservationIgnored private var inbox = IntentInbox()
    @ObservationIgnored private let session: WCSession? = WCSession.isSupported() ? .default : nil

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    /// Applies a tap from the Watch once, even if it arrives twice, then reports back.
    func handle(_ message: IntentMessage) {
        if inbox.accept(message.id), let model {
            switch message.intent {
            case .point(let side): model.rallyWon(by: side)
            case .undo: model.undo()
            case .serve: model.markRallyStart()
            }
        }
        // Always report back, so the Watch can clear the tap even if it changed nothing.
        push()
    }

    func snapshot(at date: Date = .now) -> MatchSnapshot {
        guard let model else {
            return .noMatch(handledIntentIDs: inbox.recent, isRecording: isRecording(), sentAt: date)
        }
        return MatchSnapshot(model: model, handledIntentIDs: inbox.recent, isRecording: isRecording(), sentAt: date)
    }

    /// Sends the current snapshot. The application context keeps the latest for when the
    /// Watch app next opens, and a message delivers it straight away when the Watch is reachable.
    func push() {
        guard
            let session,
            session.activationState == .activated,
            session.isPaired,
            session.isWatchAppInstalled,
            let data = try? WatchMessage.encode(snapshot())
        else { return }
        let payload = [WatchMessage.snapshotKey: data]
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }
}

extension WatchSyncService: WCSessionDelegate {
    // WatchConnectivity calls these on a background queue. Each one only pulls out
    // plain data, then hops to the main actor where the match lives.

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Happens when the user switches to another Watch. Reconnect to the new one.
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.push() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message[WatchMessage.intentKey] as? Data)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo[WatchMessage.intentKey] as? Data)
    }

    nonisolated private func receive(_ data: Data?) {
        guard let data, let message = try? WatchMessage.decode(IntentMessage.self, from: data) else { return }
        Task { @MainActor in self.handle(message) }
    }
}
