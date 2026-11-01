public enum MatchKind: String, Hashable, Sendable, Codable {
    case singles
    case doubles
}

/// One player. In singles each side has only the `.first` slot.
/// Names live in the app; ScoringKit only needs to tell players apart.
public struct Player: Hashable, Sendable, Codable {
    public enum Slot: String, Hashable, Sendable, Codable, CaseIterable {
        case first
        case second
    }

    public let side: Side
    public let slot: Slot

    public init(side: Side, slot: Slot) {
        self.side = side
        self.slot = slot
    }

    public static func singles(_ side: Side) -> Player {
        Player(side: side, slot: .first)
    }

    /// The other player on the same side (doubles).
    public var partner: Player {
        Player(side: side, slot: slot == .first ? .second : .first)
    }
}

/// The half of a side's court that the server or receiver stands in.
public enum ServiceCourt: String, Hashable, Sendable, Codable {
    case right
    case left

    /// Right when the serving side's score is even, left when odd.
    public init(forScore score: Int) {
        self = score.isMultiple(of: 2) ? .right : .left
    }

    public var other: ServiceCourt {
        self == .right ? .left : .right
    }
}
