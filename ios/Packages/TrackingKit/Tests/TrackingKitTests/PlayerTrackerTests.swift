import CoreGraphics
import Testing
@testable import TrackingKit

/// FR-27: floor halos follow each player, one halo per person, steady and on the floor.
@Suite struct PlayerTrackerTests {
    /// Analysed frames arrive about 30 times a second.
    let step = 1.0 / 30.0
    let size: CGFloat = 0.4

    private func run(_ tracker: inout PlayerTracker, frames: Int, start: Double = 0, sighting: (Int) -> [BodySighting]) -> [PlayerMark] {
        var marks: [PlayerMark] = []
        for frame in 0..<frames {
            marks = tracker.update(with: sighting(frame), at: start + Double(frame) * step)
        }
        return marks
    }

    @Test func aStandingPlayerKeepsOneHaloOnTheFloor() throws {
        var tracker = PlayerTracker()
        let marks = run(&tracker, frames: 30) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        #expect(marks.count == 1)
        let center = try #require(marks.first).center
        #expect(abs(center.x - 0.5) < 0.001)
        // Moved down from the ankles to where the feet meet the floor.
        #expect(abs(center.y - (0.8 + PlayerTracker.ankleToFloor * size)) < 0.001)
    }

    @Test func aFastMoverKeepsOneHalo() {
        var tracker = PlayerTracker()
        var ids = Set<Int>()
        // A quick sideways move: 0.06 of the image width every analysed frame.
        for frame in 0..<12 {
            let feet = CGPoint(x: 0.1 + 0.06 * CGFloat(frame), y: 0.8)
            let marks = tracker.update(with: [BodySighting(feet: feet, size: size)], at: Double(frame) * step)
            #expect(marks.count == 1)
            ids.formUnion(marks.map(\.id))
        }
        #expect(ids.count == 1)
    }

    @Test func aHaloDisappearsSoonAfterThePlayerIsLost() {
        var tracker = PlayerTracker()
        _ = run(&tracker, frames: 10) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        let shortlyAfter = tracker.update(with: [], at: 10 * step + 0.1)
        #expect(shortlyAfter.count == 1)
        let later = tracker.update(with: [], at: 10 * step + 0.5)
        #expect(later.isEmpty)
    }

    @Test func twoPlayersKeepTheirOwnHalos() {
        var tracker = PlayerTracker()
        let marks = run(&tracker, frames: 20) { frame in
            [
                BodySighting(feet: CGPoint(x: 0.2, y: 0.8 - 0.002 * CGFloat(frame)), size: size),
                BodySighting(feet: CGPoint(x: 0.7, y: 0.5), size: 0.2),
            ]
        }
        #expect(marks.count == 2)
        #expect(Set(marks.map(\.id)).count == 2)
    }

    @Test func jitterIsSmoothedWhileStandingStill() {
        var tracker = PlayerTracker()
        var xs: [CGFloat] = []
        for frame in 0..<60 {
            // Ankle points wobble by about 1% of the image every frame.
            let wobble: CGFloat = frame.isMultiple(of: 2) ? 0.01 : -0.01
            let marks = tracker.update(with: [BodySighting(feet: CGPoint(x: 0.5 + wobble, y: 0.8), size: size)], at: Double(frame) * step)
            if frame >= 30, let mark = marks.first { xs.append(mark.center.x) }
        }
        let spread = (xs.max() ?? 0) - (xs.min() ?? 0)
        #expect(spread < 0.008, "halo moved \(spread) for a wobble of 0.02")
    }

    @Test func walkingAwayFromTheCameraIsNotAJump() {
        var tracker = PlayerTracker()
        // Walking away: the feet rise up the picture slowly and steadily.
        for frame in 0..<60 {
            let feet = CGPoint(x: 0.5, y: 0.85 - 0.004 * CGFloat(frame))
            let marks = tracker.update(with: [BodySighting(feet: feet, size: size)], at: Double(frame) * step)
            #expect(marks.first?.isHeld == false)
        }
    }

    @Test func aJumpHoldsTheHaloAtTheTakeOffSpot() throws {
        var tracker = PlayerTracker()
        _ = run(&tracker, frames: 15) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        let takeOff = try #require(tracker.update(with: [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)], at: 15 * step).first).center

        // The feet shoot up a fifth of the body height in 2 frames, drifting sideways.
        var held: [PlayerMark] = []
        for frame in 16..<22 {
            let rise = min(CGFloat(frame - 15) * 0.04, 0.12)
            let feet = CGPoint(x: 0.5 + 0.01 * CGFloat(frame - 15), y: 0.8 - rise)
            held += tracker.update(with: [BodySighting(feet: feet, size: size)], at: Double(frame) * step)
        }
        #expect(held.allSatisfy { $0.isHeld })
        #expect(held.allSatisfy { abs($0.center.x - takeOff.x) < 0.005 && abs($0.center.y - takeOff.y) < 0.005 })

        // Landing releases the hold.
        let landed = run(&tracker, frames: 10, start: 22 * step) { _ in [BodySighting(feet: CGPoint(x: 0.56, y: 0.8), size: size)] }
        #expect(landed.first?.isHeld == false)
    }

    @Test func aHoldNeverLastsLongerThanAJump() {
        var tracker = PlayerTracker()
        _ = run(&tracker, frames: 15) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        _ = tracker.update(with: [BodySighting(feet: CGPoint(x: 0.5, y: 0.7), size: size)], at: 15 * step)
        // The feet stay up (say, the player stepped onto something). The hold gives up.
        let marks = run(&tracker, frames: 40, start: 16 * step) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.7), size: size)] }
        #expect(marks.first?.isHeld == false)
    }

    @Test func twoHalosOnOnePersonAreMerged() {
        var tracker = PlayerTracker()
        // Two people far apart, then one walks onto the other's spot and the other vanishes.
        _ = run(&tracker, frames: 5) { _ in
            [BodySighting(feet: CGPoint(x: 0.3, y: 0.8), size: size), BodySighting(feet: CGPoint(x: 0.7, y: 0.8), size: size)]
        }
        let marks = run(&tracker, frames: 5, start: 5 * step) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        #expect(marks.count <= 1 || Set(marks.map(\.id)).count == marks.count)
        let later = run(&tracker, frames: 15, start: 10 * step) { _ in [BodySighting(feet: CGPoint(x: 0.5, y: 0.8), size: size)] }
        #expect(later.count == 1)
    }
}
