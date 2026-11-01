import Foundation
import Observation
import WatchConnectivity
import WatchKit
import WatchLink

/// The Watch side of sync (FR-05, FR-07). The Watch is a scoring remote:
/// it sends taps to the iPhone and shows whatever snapshot the iPhone sends back.
/// It never works out a score itself.
@Observable
final class WatchSession: NSObject {
    /// The latest snapshot from the iPhone, or nil before the first one arrives.
    private(set) var snapshot: MatchSnapshot?
    /// Taps sent but not yet confirmed by the iPhone.
    private(set) var pending = PendingIntents()
    private(set) var isReachable = false

    @ObservationIgnored private let session = WCSession.default

    func activate() {
        session.delegate = self
        session.activate()
    }

    func send(_ intent: WatchIntent) {
        let message = IntentMessage(intent: intent)
        pending.add(message)
        guard let data = try? WatchMessage.encode(message) else { return }

        if session.activationState == .activated && session.isReachable {
            session.sendMessage([WatchMessage.intentKey: data], replyHandler: nil) { [weak self] _ in
                // The live message failed, so queue it instead. If both arrive, the iPhone ignores the repeat.
                Task { @MainActor in self?.queue(data) }
            }
        } else {
            queue(data)
        }
    }

    /// Queued messages are delivered in order once the iPhone is back in reach.
    private func queue(_ data: Data) {
        session.transferUserInfo([WatchMessage.intentKey: data])
    }

    func receive(_ snapshot: MatchSnapshot) {
        guard snapshot.isNewer(than: self.snapshot) else { return }
        let previousRallies = self.snapshot?.rallyCount
        self.snapshot = snapshot
        pending.confirm(from: snapshot)
        if let previousRallies, previousRallies != snapshot.rallyCount {
            WKInterfaceDevice.current().play(.click)
        }
    }
}

extension WatchSession: WCSessionDelegate {
    // WatchConnectivity calls these on a background queue. Each one only pulls out
    // plain values, then hops to the main actor.

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let data = session.receivedApplicationContext[WatchMessage.snapshotKey] as? Data
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            self.receive(data)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchMessage.snapshotKey] as? Data
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let data = message[WatchMessage.snapshotKey] as? Data
        Task { @MainActor in self.receive(data) }
    }

    private func receive(_ data: Data?) {
        guard let data, let snapshot = try? WatchMessage.decode(MatchSnapshot.self, from: data) else { return }
        receive(snapshot)
    }
}
