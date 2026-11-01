import Foundation
import CoreGraphics
import Testing
@testable import TrackingKit

/// FR-13 and FR-14: court calibration, true floor circles, and the court mask.
@Suite struct CourtCalibrationTests {
    /// A doubles court seen from behind the baseline: the far end narrower and higher in the picture.
    let calibration = CourtCalibration(
        imageCorners: [CGPoint(x: 0.40, y: 0.30), CGPoint(x: 0.60, y: 0.30), CGPoint(x: 0.90, y: 0.90), CGPoint(x: 0.10, y: 0.90)],
        courtSize: CourtCalibration.doublesSize,
        imageAspect: 9.0 / 16.0
    )

    private func close(_ a: CGPoint?, _ b: CGPoint, within limit: CGFloat = 1e-6) -> Bool {
        guard let a else { return false }
        return abs(a.x - b.x) < limit && abs(a.y - b.y) < limit
    }

    @Test func cornersMapExactlyBothWays() throws {
        let toImage = try #require(calibration.courtToImage)
        let toCourt = try #require(calibration.imageToCourt)
        for (court, image) in zip(calibration.courtCorners, calibration.imageCorners) {
            #expect(close(toImage.map(court), image))
            #expect(close(toCourt.map(image), court))
        }
    }

    @Test func aPointRoundTrips() throws {
        let spot = CGPoint(x: 2.3, y: 9.1)
        let image = try #require(calibration.courtToImage?.map(spot))
        #expect(close(calibration.courtPoint(forImage: image), spot, within: 1e-9))
    }

    @Test func theNetIsAboveHalfwayInThePicture() throws {
        // Perspective: the court's middle sits nearer the far end on screen.
        let net = try #require(calibration.courtToImage?.map(CGPoint(x: 3.05, y: 6.70)))
        #expect(net.y < 0.60)
    }

    @Test func aFloorCircleIsWiderNearTheCamera() throws {
        let toImage = try #require(calibration.courtToImage)
        func ringWidth(atCourt spot: CGPoint) throws -> CGFloat {
            let center = try #require(toImage.map(spot))
            let ring = try #require(calibration.floorRing(aroundImagePoint: center, diameter: 0.8))
            return ring.map(\.x).max()! - ring.map(\.x).min()!
        }
        #expect(try ringWidth(atCourt: CGPoint(x: 3, y: 12)) > ringWidth(atCourt: CGPoint(x: 3, y: 2)) * 1.5)
    }

    @Test func aFloorCircleIsFlatterThanItIsWide() throws {
        let center = try #require(calibration.courtToImage?.map(CGPoint(x: 3, y: 10)))
        let ring = try #require(calibration.floorRing(aroundImagePoint: center, diameter: 0.8))
        let width = ring.map(\.x).max()! - ring.map(\.x).min()!
        let height = ring.map(\.y).max()! - ring.map(\.y).min()!
        #expect(height < width)
    }

    @Test func theMaskKeepsPlayersNearTheCourt() throws {
        let toImage = try #require(calibration.courtToImage)
        let onCourt = try #require(toImage.map(CGPoint(x: 1, y: 3)))
        let justBehindBaseline = try #require(toImage.map(CGPoint(x: 3, y: 14.2)))
        let nextCourt = try #require(toImage.map(CGPoint(x: -4, y: 6)))
        #expect(calibration.isOnCourt(imagePoint: onCourt, margin: 1.5))
        #expect(calibration.isOnCourt(imagePoint: justBehindBaseline, margin: 1.5))
        #expect(!calibration.isOnCourt(imagePoint: nextCourt, margin: 1.5))
    }

    @Test func aTwistedShapeIsNotValid() {
        var twisted = calibration
        twisted.imageCorners.swapAt(2, 3)
        #expect(calibration.isValid)
        #expect(!twisted.isValid)
    }

    @Test func threeCornersOnALineAreNotValid() {
        let line = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.9, y: 0.1), CGPoint(x: 0.5, y: 0.8)]
        let flat = CourtCalibration(imageCorners: line, courtSize: CourtCalibration.doublesSize, imageAspect: 1)
        // A mapping exists, but it squashes the court flat, so it cannot be undone.
        #expect(!flat.isValid)
        #expect(flat.imageToCourt == nil)
    }

    @Test func aTurnedPhoneDoesNotFit() {
        let portrait: CGFloat = 1080.0 / 1920.0
        let landscape: CGFloat = 1920.0 / 1080.0
        let fitsPortrait = calibration.fits(imageAspect: portrait)
        let fitsLandscape = calibration.fits(imageAspect: landscape)
        #expect(fitsPortrait)
        #expect(fitsLandscape == false)
    }

    @Test func calibrationSurvivesEncoding() throws {
        let data = try JSONEncoder().encode(calibration)
        #expect(try JSONDecoder().decode(CourtCalibration.self, from: data) == calibration)
    }
}
