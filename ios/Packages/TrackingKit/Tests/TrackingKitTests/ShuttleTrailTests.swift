import CoreGraphics
import Testing
@testable import TrackingKit

/// FR-27 shuttle trial: a circle and a short trail, without jumping between unrelated objects.
@Suite struct ShuttleTrailTests {
    let step = 1.0 / 30.0

    private func candidate(_ x: CGFloat, _ y: CGFloat, confidence: Float = 0.95) -> ShuttleCandidate {
        ShuttleCandidate(point: CGPoint(x: x, y: y), confidence: confidence)
    }

    @Test func aSteadyFlightBuildsATrail() {
        var shuttle = ShuttleTrail()
        for frame in 0..<6 {
            shuttle.update(with: [candidate(0.2 + 0.03 * CGFloat(frame), 0.4)], at: Double(frame) * step)
        }
        #expect(shuttle.trail.count == 6)
        #expect(shuttle.current != nil)
    }

    @Test func noCircleUntilThreePointsAgree() {
        var shuttle = ShuttleTrail()
        shuttle.update(with: [candidate(0.2, 0.4)], at: 0)
        shuttle.update(with: [candidate(0.23, 0.4)], at: step)
        #expect(shuttle.current == nil)
        shuttle.update(with: [candidate(0.26, 0.4)], at: 2 * step)
        #expect(shuttle.current != nil)
    }

    @Test func aFarAwayPointStartsANewTrailInsteadOfJoining() {
        var shuttle = ShuttleTrail()
        for frame in 0..<4 {
            shuttle.update(with: [candidate(0.2 + 0.03 * CGFloat(frame), 0.4)], at: Double(frame) * step)
        }
        shuttle.update(with: [candidate(0.9, 0.9)], at: 4 * step)
        #expect(shuttle.trail.count == 1)
        #expect(shuttle.current == nil)
    }

    @Test func theCandidateNearestTheTrailWins() {
        var shuttle = ShuttleTrail()
        for frame in 0..<3 {
            shuttle.update(with: [candidate(0.2 + 0.03 * CGFloat(frame), 0.4)], at: Double(frame) * step)
        }
        shuttle.update(with: [candidate(0.29, 0.4, confidence: 0.91), candidate(0.8, 0.1, confidence: 0.99)], at: 3 * step)
        #expect(shuttle.trail.last == CGPoint(x: 0.29, y: 0.4))
    }

    @Test func noisyFramesAreIgnored() {
        var shuttle = ShuttleTrail()
        let noise = (0..<20).map { candidate(CGFloat($0) * 0.04, 0.5) }
        shuttle.update(with: noise, at: 0)
        #expect(shuttle.trail.isEmpty)
    }

    @Test func lowConfidenceCandidatesAreIgnored() {
        var shuttle = ShuttleTrail()
        shuttle.update(with: [candidate(0.2, 0.4, confidence: 0.5)], at: 0)
        #expect(shuttle.trail.isEmpty)
    }

    @Test func theTrailFadesAfterTheShuttleIsLost() {
        var shuttle = ShuttleTrail()
        for frame in 0..<4 {
            shuttle.update(with: [candidate(0.2 + 0.03 * CGFloat(frame), 0.4)], at: Double(frame) * step)
        }
        shuttle.update(with: [], at: 4 * step)
        #expect(shuttle.current == nil)
        #expect(!shuttle.trail.isEmpty)
        shuttle.update(with: [], at: 1.0)
        #expect(shuttle.trail.isEmpty)
    }
}
