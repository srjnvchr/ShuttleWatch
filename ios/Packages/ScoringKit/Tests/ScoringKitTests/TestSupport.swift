@testable import ScoringKit

extension Match {
    static func singles(games: Int = 1, firstServer: Side = .a) throws -> Match {
        Match(setup: MatchSetup(
            kind: .singles,
            format: try MatchFormat.standard.with(gamesPerMatch: games),
            firstServingSide: firstServer
        ))
    }

    /// Records `count` rallies won by `side`.
    mutating func win(_ side: Side, _ count: Int = 1) throws {
        for _ in 0..<count {
            try record(.rallyWon(by: side))
        }
    }

    /// Records one rally per character: "a" or "b" names the winner.
    mutating func play(_ winners: String) throws {
        for character in winners {
            try win(character == "a" ? .a : .b)
        }
    }
}
