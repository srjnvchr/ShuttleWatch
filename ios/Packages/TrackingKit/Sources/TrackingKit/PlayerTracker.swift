import CoreGraphics
import Foundation

/// Follows players from frame to frame and decides where each halo sits.
/// Pure logic with no Vision, so it can be tested with made-up sightings.
/// Works in seconds rather than frames, so it behaves the same at any analysis rate.
public struct PlayerTracker: Sendable {
    // Distances are fractions of the image. `size` is a player's height in the image.

    /// Ankles sit above the floor. The halo moves down by this share of the player's height.
    static let ankleToFloor: CGFloat = 0.04
    /// A sighting this close to where a player was heading counts as the same player,
    /// as a share of their height. Near players are bigger, so they may move further.
    static let matchShareOfSize: CGFloat = 0.8
    static let minimumMatchDistance: CGFloat = 0.05
    /// How long a halo stays after its player was last seen.
    static let keepUnseen: TimeInterval = 0.35
    /// Two halos closer than this share of the player's height are one person.
    static let mergeShareOfSize: CGFloat = 0.3
    /// Feet rising faster than this many player heights a second means a jump.
    /// Walking away from the camera also moves the feet up the picture, but far slower.
    static let jumpSpeed: CGFloat = 1.2
    /// The feet must also have risen this share of the player's height.
    static let jumpRise: CGFloat = 0.06
    /// The feet count as landed within this share of the player's height of take-off.
    static let landingMargin: CGFloat = 0.1
    /// No real jump lasts longer than this. After it, the hold gives up.
    static let longestJump: TimeInterval = 1.0

    private struct Hold: Sendable {
        let center: CGPoint
        let takeOffFeetY: CGFloat
        let started: TimeInterval
    }

    private struct Track: Sendable {
        let id: Int
        let firstSeen: TimeInterval
        var lastSeen: TimeInterval
        var lastFeet: CGPoint
        /// Image fractions per second, smoothed.
        var velocity: CGVector
        var size: CGFloat
        var smoothX: OneEuroFilter
        var smoothY: OneEuroFilter
        var center: CGPoint
        var hold: Hold?

        func predictedFeet(at time: TimeInterval) -> CGPoint {
            let ahead = CGFloat(min(time - lastSeen, 0.2))
            return CGPoint(x: lastFeet.x + velocity.dx * ahead, y: lastFeet.y + velocity.dy * ahead)
        }
    }

    private var tracks: [Track] = []
    private var nextID = 0

    public init() {}

    public mutating func reset() {
        tracks = []
    }

    public mutating func update(with sightings: [BodySighting], at time: TimeInterval) -> [PlayerMark] {
        // Pair players and sightings, closest pairs first, each within its player's reach.
        var pairs: [(track: Int, sighting: Int, distance: CGFloat)] = []
        for (trackIndex, track) in tracks.enumerated() {
            let reach = max(Self.minimumMatchDistance, track.size * Self.matchShareOfSize)
            let predicted = track.predictedFeet(at: time)
            for (sightingIndex, sighting) in sightings.enumerated() {
                let distance = Self.distance(predicted, sighting.feet)
                if distance < reach {
                    pairs.append((trackIndex, sightingIndex, distance))
                }
            }
        }
        var pairedTracks = Set<Int>()
        var pairedSightings = Set<Int>()
        for pair in pairs.sorted(by: { $0.distance < $1.distance })
        where !pairedTracks.contains(pair.track) && !pairedSightings.contains(pair.sighting) {
            pairedTracks.insert(pair.track)
            pairedSightings.insert(pair.sighting)
            Self.update(&tracks[pair.track], with: sightings[pair.sighting], at: time)
        }

        for (index, sighting) in sightings.enumerated() where !pairedSightings.contains(index) {
            tracks.append(Self.newTrack(id: nextID, sighting: sighting, at: time))
            nextID += 1
        }

        tracks.removeAll { time - $0.lastSeen > Self.keepUnseen }
        mergeDuplicates()

        return tracks.map { track in
            PlayerMark(id: track.id, center: track.hold?.center ?? track.center, size: track.size, isHeld: track.hold != nil)
        }
    }

    private static func newTrack(id: Int, sighting: BodySighting, at time: TimeInterval) -> Track {
        var track = Track(
            id: id,
            firstSeen: time,
            lastSeen: time,
            lastFeet: sighting.feet,
            velocity: .zero,
            size: sighting.size,
            smoothX: OneEuroFilter(),
            smoothY: OneEuroFilter(),
            center: .zero
        )
        track.center = floorPoint(of: &track, feet: sighting.feet, at: time)
        return track
    }

    private static func update(_ track: inout Track, with sighting: BodySighting, at time: TimeInterval) {
        let elapsed = CGFloat(max(time - track.lastSeen, 1.0 / 120))
        let rawVelocity = CGVector(
            dx: (sighting.feet.x - track.lastFeet.x) / elapsed,
            dy: (sighting.feet.y - track.lastFeet.y) / elapsed
        )
        track.velocity = CGVector(
            dx: track.velocity.dx * 0.5 + rawVelocity.dx * 0.5,
            dy: track.velocity.dy * 0.5 + rawVelocity.dy * 0.5
        )
        track.size = track.size * 0.8 + sighting.size * 0.2
        track.lastFeet = sighting.feet
        track.lastSeen = time

        // Up the picture means a smaller y, so rising speed is the negative of dy.
        let risingSpeed = -track.velocity.dy
        let floorFeetY = track.center.y - ankleToFloor * track.size
        if var hold = track.hold {
            let landed = sighting.feet.y >= hold.takeOffFeetY - landingMargin * track.size
            if landed || time - hold.started > longestJump {
                track.hold = nil
            } else {
                hold = Hold(center: hold.center, takeOffFeetY: hold.takeOffFeetY, started: hold.started)
                track.hold = hold
            }
        } else if risingSpeed > jumpSpeed * track.size && floorFeetY - sighting.feet.y > jumpRise * track.size {
            // Take off: keep the halo where it was, on the floor.
            track.hold = Hold(center: track.center, takeOffFeetY: floorFeetY, started: time)
        }

        // Keep the smoothing running during a jump, so the halo moves on cleanly after landing.
        track.center = floorPoint(of: &track, feet: sighting.feet, at: time)
    }

    /// The smoothed spot on the floor under the feet.
    private static func floorPoint(of track: inout Track, feet: CGPoint, at time: TimeInterval) -> CGPoint {
        CGPoint(
            x: track.smoothX.filter(feet.x, at: time),
            y: track.smoothY.filter(feet.y, at: time) + ankleToFloor * track.size
        )
    }

    /// When two halos sit on one person, keep the older one.
    private mutating func mergeDuplicates() {
        var keep: [Track] = []
        for track in tracks.sorted(by: { $0.firstSeen < $1.firstSeen }) {
            let duplicate = keep.contains { kept in
                Self.distance(kept.center, track.center) < Self.mergeShareOfSize * max(kept.size, track.size)
            }
            if !duplicate {
                keep.append(track)
            }
        }
        tracks = keep
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
