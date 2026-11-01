import Foundation

/// One continuous recording. A match can have several if recording is stopped and started.
nonisolated struct RecordingSegment: Hashable, Codable, Sendable {
    let fileName: String
    /// Wall-clock time of the first frame: time zero of this video.
    let startedAt: Date
    let endedAt: Date
}

/// Training data kept beside a match (FR-11). These are not scoring rules, so they live in
/// the app rather than in ScoringKit, and never affect the score.
nonisolated struct MatchLabels: Hashable, Codable {
    /// The match's folder in Documents/Recordings, for example "2026-11-01 1430 Priya vs Sam".
    var folderName: String
    /// Whether the players tap Serve at the start of each rally.
    var marksRallyStarts: Bool
    /// Serve taps, keyed by the position in `match.events` of the point that ended that rally.
    var rallyStarts: [Int: Date] = [:]
    var recordings: [RecordingSegment] = []

    init(folderName: String, marksRallyStarts: Bool) {
        self.folderName = folderName
        self.marksRallyStarts = marksRallyStarts
    }

    /// Local date and 24-hour time, so folders sort in order: "2026-11-01 1715 Priya vs Sam".
    static func folderName(title: String, startedAt: Date) -> String {
        let safeTitle = title.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        return "\(localStamp(startedAt, timeSeparator: "")) \(safeTitle)"
    }

    /// For example "2026-11-01 1715", or "2026-11-01 171542" with seconds.
    static func localStamp(_ date: Date, timeSeparator: String, seconds: Bool = false) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var text = String(format: "%04d-%02d-%02d %02d%@%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, timeSeparator, parts.minute ?? 0)
        if seconds {
            text += String(format: "%@%02d", timeSeparator, parts.second ?? 0)
        }
        return text
    }
}

/// Where recordings and their labels live. Documents is visible in Finder when the
/// iPhone is plugged in, which is how footage gets to the Mac (FR-12, NFR-06).
enum RecordingStore {
    static var root: URL {
        URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    static func folder(named name: String) -> URL {
        root.appending(path: name, directoryHint: .isDirectory)
    }

    /// Removes a match's videos and labels, for example when the match is deleted.
    static func deleteFolder(named name: String) {
        try? FileManager.default.removeItem(at: folder(named: name))
    }
}
