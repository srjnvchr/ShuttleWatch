import Foundation
import ScoringKit

/// Display names for the players. ScoringKit only knows sides and slots.
struct PlayerNames: Hashable, Codable {
    private var names: [Player: String] = [:]

    init(_ names: [Player: String] = [:]) {
        for (player, name) in names {
            self[player] = name
        }
    }

    /// Stores trimmed names. An empty name falls back to a default.
    subscript(player: Player) -> String? {
        get { names[player] }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            names[player] = trimmed.isEmpty ? nil : trimmed
        }
    }

    func name(of player: Player, kind: MatchKind) -> String {
        if let name = names[player] {
            return name
        }
        let side = player.side.rawValue.uppercased()
        switch kind {
        case .singles: return "Side \(side)"
        case .doubles: return side + (player.slot == .first ? "1" : "2")
        }
    }

    /// One player's name in singles, both names joined in doubles.
    func name(of side: Side, kind: MatchKind) -> String {
        switch kind {
        case .singles:
            return name(of: .singles(side), kind: kind)
        case .doubles:
            let first = name(of: Player(side: side, slot: .first), kind: kind)
            let second = name(of: Player(side: side, slot: .second), kind: kind)
            return "\(first) & \(second)"
        }
    }
}
