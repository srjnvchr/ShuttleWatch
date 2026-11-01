import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import TrackingKit
import UniformTypeIdentifiers

/// Runs the app's tracking on a recorded video, so fixes can be tested on the same footage
/// again and again (FR-26).
///
///     swift run track-video <video.mov> <output folder> [--every 2] [--snapshot-every 1] [--no-video]
///
/// Writes overlay.mov, a PNG snapshot every few seconds, and frames.jsonl with what Vision
/// found and where each halo and the shuttle trail ended up, one line per analysed frame.
@main
struct TrackVideo {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            try await run(options)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ options: Options) async throws {
        let asset = AVURLAsset(url: options.input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ToolError("No video track in \(options.input.path)")
        }
        let frameRate = try await track.load(.nominalFrameRate)
        if try await track.load(.preferredTransform) != .identity {
            print("note: this video has a rotation transform. Points follow the stored pixels, not the display.")
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        reader.add(output)
        guard reader.startReading() else { throw ToolError("Cannot read \(options.input.path)") }

        try FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
        let log = try LineWriter(url: options.output.appending(path: "frames.jsonl"))
        var writer: OverlayWriter?
        let tracker = CourtTracker()
        var stats = Stats()
        var latest: (frame: TrackingFrame, analysis: FrameAnalysis)?
        var nextSnapshot = 0.0
        var frameIndex = 0

        while let sample = output.copyNextSampleBuffer() {
            defer { frameIndex += 1 }
            guard let pixels = CMSampleBufferGetImageBuffer(sample) else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            let seconds = time.seconds

            // Same rhythm as the app: analyse every second frame, draw the latest result on every frame.
            if frameIndex.isMultiple(of: options.every) {
                let started = Date.now
                if let result = tracker.process(sample) {
                    stats.add(result, milliseconds: Date.now.timeIntervalSince(started) * 1000)
                    latest = result
                    try log.write(FrameLog(frame: frameIndex, seconds: seconds, analysis: result.analysis, tracking: result.frame))
                }
            }

            let image = Drawing.overlay(latest, on: pixels)
            if seconds >= nextSnapshot, let image {
                try Drawing.savePNG(image, to: options.output.appending(path: String(format: "snapshot-%06.2fs.png", seconds)))
                nextSnapshot += options.snapshotEvery
            }
            if options.writeVideo {
                if writer == nil {
                    writer = try OverlayWriter(
                        url: options.output.appending(path: "overlay.mov"),
                        width: CVPixelBufferGetWidth(pixels),
                        height: CVPixelBufferGetHeight(pixels),
                        start: time
                    )
                }
                writer?.append(pixels, at: time)
            }
        }

        await writer?.finish()
        try log.close()
        print(stats.summary(frames: frameIndex, frameRate: frameRate, every: options.every))
        for (reason, count) in tracker.failures.sorted(by: { $0.value > $1.value }) {
            print("Failed \(count) times: \(reason)")
        }
        print("Wrote \(options.output.path)")
    }
}

struct Options {
    var input: URL
    var output: URL
    var every = 2
    var snapshotEvery = 1.0
    var writeVideo = true

    init(arguments: [String]) throws {
        var positional: [String] = []
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--every":
                guard let value = iterator.next().flatMap(Int.init), value > 0 else { throw ToolError("--every needs a whole number") }
                every = value
            case "--snapshot-every":
                guard let value = iterator.next().flatMap(Double.init), value > 0 else { throw ToolError("--snapshot-every needs seconds") }
                snapshotEvery = value
            case "--no-video":
                writeVideo = false
            default:
                positional.append(argument)
            }
        }
        guard positional.count == 2 else {
            throw ToolError("usage: track-video <video.mov> <output folder> [--every 2] [--snapshot-every 1] [--no-video]")
        }
        input = URL(filePath: positional[0])
        output = URL(filePath: positional[1], directoryHint: .isDirectory)
    }
}

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct FrameLog: Encodable {
    let frame: Int
    let seconds: Double
    let analysis: FrameAnalysis
    let tracking: TrackingFrame
}

/// Counts that show the halo and shuttle problems as numbers.
struct Stats {
    var analysed = 0
    var totalMilliseconds = 0.0
    var slowest = 0.0
    var framesWithMoreHalosThanPeople = 0
    var trackIDs = Set<Int>()
    var framesWithShuttleCandidates = 0
    var halosHeld = 0
    var haloSteps: [Double] = []
    private var lastCenters: [Int: CGPoint] = [:]

    mutating func add(_ result: (frame: TrackingFrame, analysis: FrameAnalysis), milliseconds: Double) {
        analysed += 1
        totalMilliseconds += milliseconds
        slowest = max(slowest, milliseconds)
        if result.frame.players.count > result.analysis.sightings.count {
            framesWithMoreHalosThanPeople += 1
        }
        if !result.analysis.candidates.isEmpty {
            framesWithShuttleCandidates += 1
        }
        for mark in result.frame.players {
            trackIDs.insert(mark.id)
            if mark.isHeld { halosHeld += 1 }
            if let previous = lastCenters[mark.id] {
                haloSteps.append(hypot(mark.center.x - previous.x, mark.center.y - previous.y))
            }
            lastCenters[mark.id] = mark.center
        }
    }

    func summary(frames: Int, frameRate: Float, every: Int) -> String {
        let average = analysed > 0 ? totalMilliseconds / Double(analysed) : 0
        let sortedSteps = haloSteps.sorted()
        let medianStep = sortedSteps.isEmpty ? 0 : sortedSteps[sortedSteps.count / 2]
        return """
        Frames: \(frames) at \(Int(frameRate.rounded())) fps, analysed every \(every): \(analysed)
        Analysis time: \(String(format: "%.1f", average)) ms average, \(String(format: "%.1f", slowest)) ms slowest
        Halo IDs used: \(trackIDs.count)  (one per real person is the goal)
        Frames with more halos than people seen: \(framesWithMoreHalosThanPeople)
        Halo frames held as airborne: \(halosHeld)
        Median halo movement between analysed frames: \(String(format: "%.4f", medianStep)) (jitter shows up here when standing still)
        Frames with shuttle candidates: \(framesWithShuttleCandidates)
        """
    }
}

/// Writes one JSON object per line.
final class LineWriter {
    private let handle: FileHandle
    private let encoder = JSONEncoder()

    init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        encoder.outputFormatting = [.sortedKeys]
    }

    func write(_ value: some Encodable) throws {
        try handle.write(contentsOf: encoder.encode(value) + Data("\n".utf8))
    }

    func close() throws {
        try handle.close()
    }
}

/// Saves frames with the overlay drawn in as a video.
final class OverlayWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor

    init(url: URL, width: Int, height: Int, start: CMTime) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        guard writer.startWriting() else { throw ToolError("Cannot write \(url.path)") }
        writer.startSession(atSourceTime: start)
    }

    func append(_ pixels: CVPixelBuffer, at time: CMTime) {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }
        adaptor.append(pixels, withPresentationTime: time)
    }

    func finish() async {
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
    }
}

/// Draws the overlay straight into a video frame. Same look as the app, plus debug marks:
/// small magenta dots for the raw feet Vision found, red dots for raw shuttle candidates,
/// and orange halos while a halo is held as airborne.
enum Drawing {
    static func overlay(_ result: (frame: TrackingFrame, analysis: FrameAnalysis)?, on pixels: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let width = CVPixelBufferGetWidth(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixels),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        if let result {
            // Flip so the origin is at the top left, like the tracking points.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            let size = CGSize(width: width, height: height)
            func point(_ normalized: CGPoint) -> CGPoint {
                CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
            }

            context.setLineWidth(4)
            for mark in result.frame.players {
                let center = point(mark.center)
                let ringWidth = max(mark.size * size.height * 0.6, 24)
                let ring = CGRect(x: center.x - ringWidth / 2, y: center.y - ringWidth * 0.15, width: ringWidth, height: ringWidth * 0.3)
                context.setStrokeColor(mark.isHeld ? CGColor(red: 1, green: 0.55, blue: 0, alpha: 1) : CGColor(red: 0, green: 0.85, blue: 1, alpha: 1))
                context.strokeEllipse(in: ring)
            }

            context.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1))
            for sighting in result.analysis.sightings {
                let feet = point(sighting.feet)
                context.fillEllipse(in: CGRect(x: feet.x - 6, y: feet.y - 6, width: 12, height: 12))
            }

            context.setFillColor(CGColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
            for candidate in result.analysis.candidates {
                let spot = point(candidate.point)
                context.fillEllipse(in: CGRect(x: spot.x - 5, y: spot.y - 5, width: 10, height: 10))
            }

            let trail = result.frame.trail.map(point)
            context.setStrokeColor(CGColor(red: 1, green: 0.85, blue: 0, alpha: 1))
            context.setLineWidth(3)
            for index in trail.indices.dropFirst() {
                context.strokeLineSegments(between: [trail[index - 1], trail[index]])
            }
            if let shuttle = result.frame.shuttle {
                let spot = point(shuttle)
                context.strokeEllipse(in: CGRect(x: spot.x - 18, y: spot.y - 18, width: 36, height: 36))
            }
        }
        return context.makeImage()
    }

    static func savePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ToolError("Cannot write \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ToolError("Cannot write \(url.path)") }
    }
}
