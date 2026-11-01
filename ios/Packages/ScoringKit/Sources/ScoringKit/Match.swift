/// A match: its setup plus the events recorded so far.
/// The state is always worked out from the events, so undo only has to drop the last one.
public struct Match: Hashable, Sendable {
    public let setup: MatchSetup
    public private(set) var events: [MatchEvent] = []
    public private(set) var state: MatchState

    public init(setup: MatchSetup) {
        self.setup = setup
        state = MatchState(setup: setup)
    }

    /// Rebuilds a match from stored events, checking each one is allowed.
    public init(setup: MatchSetup, events: [MatchEvent]) throws(ScoringError) {
        self.init(setup: setup)
        for event in events {
            try record(event)
        }
    }

    /// Adds an event, or throws without changing anything if the rules do not allow it.
    public mutating func record(_ event: MatchEvent) throws(ScoringError) {
        var next = state
        try next.apply(event)
        events.append(event)
        state = next
    }

    public var canUndo: Bool {
        !events.isEmpty
    }

    /// Removes the last event and returns it, or returns nil at the start of the match.
    @discardableResult
    public mutating func undo() -> MatchEvent? {
        guard let removed = events.popLast() else { return nil }
        state = Self.replay(setup: setup, events: events)
        return removed
    }

    private static func replay(setup: MatchSetup, events: [MatchEvent]) -> MatchState {
        var state = MatchState(setup: setup)
        for event in events {
            do {
                try state.apply(event)
            } catch {
                // Every stored event passed these rules when recorded, so a prefix always replays.
                preconditionFailure("Recorded event no longer applies: \(event), \(error)")
            }
        }
        return state
    }
}

extension Match: Codable {
    private enum CodingKeys: String, CodingKey {
        case setup
        case events
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            setup: container.decode(MatchSetup.self, forKey: .setup),
            events: container.decode([MatchEvent].self, forKey: .events)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(setup, forKey: .setup)
        try container.encode(events, forKey: .events)
    }
}
