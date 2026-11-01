import Foundation

/// iPhone side: remembers recent intent IDs so a tap delivered twice is applied once.
public struct IntentInbox: Sendable {
    public private(set) var recent: [UUID] = []
    private let limit: Int

    public init(limit: Int = 100) {
        self.limit = limit
    }

    /// True the first time an ID is seen. False for a repeat.
    public mutating func accept(_ id: UUID) -> Bool {
        guard !recent.contains(id) else { return false }
        recent.append(id)
        if recent.count > limit {
            recent.removeFirst(recent.count - limit)
        }
        return true
    }
}

/// Watch side: taps sent to the iPhone that it has not confirmed yet (FR-07).
public struct PendingIntents: Sendable {
    public private(set) var messages: [IntentMessage] = []

    public init() {}

    public var count: Int { messages.count }

    public mutating func add(_ message: IntentMessage) {
        messages.append(message)
    }

    /// Drops every tap the iPhone says it has handled.
    public mutating func confirm(from snapshot: MatchSnapshot) {
        let handled = Set(snapshot.handledIntentIDs)
        messages.removeAll { handled.contains($0.id) }
    }
}
