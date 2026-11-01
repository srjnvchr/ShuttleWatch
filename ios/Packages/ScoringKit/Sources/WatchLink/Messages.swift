import Foundation
import ScoringKit

/// What the Watch asks the iPhone to do. The Watch is a scoring remote:
/// it never decides a point, and all setup happens on the iPhone.
public enum WatchIntent: Hashable, Sendable, Codable {
    case point(Side)
    case undo
}

/// One intent with an ID, so the iPhone can ignore it if it arrives twice.
public struct IntentMessage: Hashable, Sendable, Codable, Identifiable {
    public let id: UUID
    public let intent: WatchIntent
    public let sentAt: Date

    public init(intent: WatchIntent, id: UUID = UUID(), sentAt: Date = .now) {
        self.id = id
        self.intent = intent
        self.sentAt = sentAt
    }
}

/// Everything the Watch shows, as decided by the iPhone.
public struct MatchSnapshot: Hashable, Sendable, Codable {
    public enum Status: String, Hashable, Sendable, Codable {
        case noMatch
        case inPlay
        /// Doubles is waiting for the server and receiver, chosen on the iPhone.
        case awaitingGameSetup
        case matchOver
    }

    public enum Reminder: String, Hashable, Sendable, Codable {
        case interval
        case changeEnds
    }

    public var status: Status
    public var names: PerSide<String>
    public var score: PerSide<Int>
    public var gamesWon: PerSide<Int>
    public var gamesPerMatch: Int
    public var gameNumber: Int
    /// Nil when no rally can be played.
    public var servingSide: Side?
    /// For example: "Priya serves from the right".
    public var serveLine: String?
    public var reminders: [Reminder]
    /// For example: "Priya wins". Nil until the match is over.
    public var resultTitle: String?
    public var canUndo: Bool
    public var rallyCount: Int
    /// Recent intents the iPhone has handled, so the Watch can clear its waiting taps.
    public var handledIntentIDs: [UUID]
    /// When the iPhone made this snapshot. The Watch keeps only the newest.
    public var sentAt: Date

    public init(
        status: Status,
        names: PerSide<String>,
        score: PerSide<Int>,
        gamesWon: PerSide<Int>,
        gamesPerMatch: Int,
        gameNumber: Int,
        servingSide: Side?,
        serveLine: String?,
        reminders: [Reminder],
        resultTitle: String?,
        canUndo: Bool,
        rallyCount: Int,
        handledIntentIDs: [UUID],
        sentAt: Date
    ) {
        self.status = status
        self.names = names
        self.score = score
        self.gamesWon = gamesWon
        self.gamesPerMatch = gamesPerMatch
        self.gameNumber = gameNumber
        self.servingSide = servingSide
        self.serveLine = serveLine
        self.reminders = reminders
        self.resultTitle = resultTitle
        self.canUndo = canUndo
        self.rallyCount = rallyCount
        self.handledIntentIDs = handledIntentIDs
        self.sentAt = sentAt
    }

    /// Shown when no match is open on the iPhone.
    public static func noMatch(handledIntentIDs: [UUID], sentAt: Date) -> MatchSnapshot {
        MatchSnapshot(
            status: .noMatch,
            names: PerSide(a: "", b: ""),
            score: PerSide(a: 0, b: 0),
            gamesWon: PerSide(a: 0, b: 0),
            gamesPerMatch: 1,
            gameNumber: 1,
            servingSide: nil,
            serveLine: nil,
            reminders: [],
            resultTitle: nil,
            canUndo: false,
            rallyCount: 0,
            handledIntentIDs: handledIntentIDs,
            sentAt: sentAt
        )
    }

    /// Messages can arrive out of order, so an older snapshot must never replace a newer one.
    public func isNewer(than other: MatchSnapshot?) -> Bool {
        guard let other else { return true }
        return sentAt >= other.sentAt
    }
}

/// The keys and encoding used inside WatchConnectivity dictionaries.
public enum WatchMessage {
    public static let snapshotKey = "snapshot"
    public static let intentKey = "intent"

    public static func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        try JSONDecoder().decode(type, from: data)
    }
}
