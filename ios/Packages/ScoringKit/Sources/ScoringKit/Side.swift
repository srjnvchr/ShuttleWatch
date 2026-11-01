/// One of the two sides in a match: a player in singles, or a pair in doubles.
public enum Side: String, Hashable, Sendable, Codable, CaseIterable {
    case a
    case b

    public var opponent: Side {
        switch self {
        case .a: .b
        case .b: .a
        }
    }
}

/// A value for each side, such as a score or games won.
public struct PerSide<Value> {
    public var a: Value
    public var b: Value

    public init(a: Value, b: Value) {
        self.a = a
        self.b = b
    }

    public subscript(side: Side) -> Value {
        get {
            switch side {
            case .a: a
            case .b: b
            }
        }
        set {
            switch side {
            case .a: a = newValue
            case .b: b = newValue
            }
        }
    }
}

extension PerSide: Equatable where Value: Equatable {}
extension PerSide: Hashable where Value: Hashable {}
extension PerSide: Sendable where Value: Sendable {}
extension PerSide: Codable where Value: Codable {}
