import Foundation
import ScoringKit

/// Writes labels.json beside a match's videos, for the Python pipeline (FR-11, FR-12).
/// Each rally gets its winner, score, and times, both as dates and as seconds into its video.
enum LabelExport {
    struct LabelFile: Encodable, Equatable {
        struct Format: Encodable, Equatable {
            let pointsPerGame: Int
            let pointCap: Int
            let gamesPerMatch: Int
        }

        struct Video: Encodable, Equatable {
            let file: String
            let startedAt: Date
            let endedAt: Date
        }

        struct Rally: Encodable, Equatable {
            let number: Int
            let game: Int
            /// "a" or "b".
            let winner: String
            let winnerName: String
            let server: String?
            let scoreAfter: [Int]
            /// When Serve was tapped. Nil when rally starts were not marked.
            let startedAt: Date?
            /// When the point was tapped.
            let endedAt: Date
            /// Index into `videos`, or nil if the rally was not recorded.
            let video: Int?
            let startSeconds: Double?
            let endSeconds: Double?
        }

        let kind: String
        let names: [String: String]
        let format: Format
        let marksRallyStarts: Bool
        let videos: [Video]
        let rallies: [Rally]
    }

    static func labels(for model: ScoringViewModel) -> LabelFile {
        let segments = model.labels.recordings
        var replay = Match(setup: model.match.setup)
        var rallies: [LabelFile.Rally] = []

        for (index, event) in model.match.events.enumerated() {
            let before = replay.state
            guard (try? replay.record(event)) != nil else { break }
            guard case .rallyWon(let side) = event else { continue }

            let after = replay.state
            let endedGame = after.completedGames.count > before.completedGames.count
            let score = endedGame ? (after.completedGames.last?.score ?? after.score) : after.score
            let endedAt = model.eventDates[index]
            let startedAt = model.labels.rallyStarts[index]
            let video = segments.firstIndex { $0.startedAt <= endedAt && endedAt <= $0.endedAt }

            rallies.append(LabelFile.Rally(
                number: rallies.count + 1,
                game: before.gameNumber,
                winner: side.rawValue,
                winnerName: model.name(of: side),
                server: before.server.map(model.name(of:)),
                scoreAfter: [score.a, score.b],
                startedAt: startedAt,
                endedAt: endedAt,
                video: video,
                startSeconds: video.flatMap { videoIndex in
                    startedAt.map { $0.timeIntervalSince(segments[videoIndex].startedAt) }
                },
                endSeconds: video.map { endedAt.timeIntervalSince(segments[$0].startedAt) }
            ))
        }

        let format = model.match.setup.format
        return LabelFile(
            kind: model.kind.rawValue,
            names: ["a": model.name(of: .a), "b": model.name(of: .b)],
            format: .init(
                pointsPerGame: format.pointsPerGame,
                pointCap: format.pointCap,
                gamesPerMatch: format.gamesPerMatch
            ),
            marksRallyStarts: model.labels.marksRallyStarts,
            videos: segments.map { .init(file: $0.fileName, startedAt: $0.startedAt, endedAt: $0.endedAt) },
            rallies: rallies
        )
    }

    /// Saves labels.json in the match's recording folder. Only for matches with recordings.
    static func write(for model: ScoringViewModel) {
        guard !model.labels.recordings.isEmpty else { return }
        let folder = RecordingStore.folder(named: model.labels.folderName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(labels(for: model)) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appending(path: "labels.json"), options: .atomic)
    }
}
