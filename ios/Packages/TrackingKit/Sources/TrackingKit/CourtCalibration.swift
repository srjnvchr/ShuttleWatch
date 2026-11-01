import CoreGraphics
import Foundation

/// Where the court's four corners are in the camera image, and how big the court really is (FR-13).
/// From this, any spot on the floor can be turned into court metres and back.
///
/// Court coordinates are in metres: x runs across the court from the far-left corner,
/// y runs down the court towards the camera.
public struct CourtCalibration: Hashable, Sendable, Codable {
    public enum Corner: Int, CaseIterable, Sendable {
        case farLeft, farRight, nearRight, nearLeft

        public var name: String {
            switch self {
            case .farLeft: "Far left"
            case .farRight: "Far right"
            case .nearRight: "Near right"
            case .nearLeft: "Near left"
            }
        }
    }

    /// Standard badminton courts. Any rectangle works, such as a rug for testing at home.
    public static let doublesSize = CGSize(width: 6.10, height: 13.40)
    public static let singlesSize = CGSize(width: 5.18, height: 13.40)

    /// Image points, 0 to 1 with the origin top left, in `Corner` order.
    public var imageCorners: [CGPoint]
    /// Width (across) and length (towards the camera), in metres.
    public var courtSize: CGSize
    /// The image's width divided by height when calibrated. A different shape means the
    /// phone was turned, so the calibration no longer fits.
    public var imageAspect: CGFloat

    public init(imageCorners: [CGPoint], courtSize: CGSize, imageAspect: CGFloat) {
        self.imageCorners = imageCorners
        self.courtSize = courtSize
        self.imageAspect = imageAspect
    }

    /// The court's corners in metres, in `Corner` order.
    public var courtCorners: [CGPoint] {
        [
            CGPoint(x: 0, y: 0),
            CGPoint(x: courtSize.width, y: 0),
            CGPoint(x: courtSize.width, y: courtSize.height),
            CGPoint(x: 0, y: courtSize.height),
        ]
    }

    public var courtToImage: Homography? {
        Homography(from: courtCorners, to: imageCorners)
    }

    public var imageToCourt: Homography? {
        courtToImage?.inverted
    }

    /// Usable when the four corners form a proper four-sided shape that is not twisted.
    public var isValid: Bool {
        guard imageCorners.count == 4, courtSize.width > 0, courtSize.height > 0, courtToImage != nil else {
            return false
        }
        // A convex shape turns the same way at every corner.
        let turns = (0..<4).map { index -> CGFloat in
            let a = imageCorners[index], b = imageCorners[(index + 1) % 4], c = imageCorners[(index + 2) % 4]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
        }
        return turns.allSatisfy { $0 > 0 } || turns.allSatisfy { $0 < 0 }
    }

    /// True when this calibration was made for images of this shape.
    public func fits(imageAspect other: CGFloat) -> Bool {
        abs(imageAspect - other) < 0.02
    }

    /// The court position, in metres, of a floor point in the image.
    public func courtPoint(forImage point: CGPoint) -> CGPoint? {
        imageToCourt?.map(point)
    }

    /// True when a floor point is on the court or within `margin` metres of its lines.
    public func isOnCourt(imagePoint: CGPoint, margin: CGFloat) -> Bool {
        guard let spot = courtPoint(forImage: imagePoint) else { return false }
        return spot.x >= -margin && spot.x <= courtSize.width + margin
            && spot.y >= -margin && spot.y <= courtSize.height + margin
    }

    /// A circle lying on the floor, `diameter` metres across, centred on a floor point in the image.
    /// Returned as image points, so it shows true perspective. Nil if it cannot be drawn.
    public func floorRing(aroundImagePoint center: CGPoint, diameter: CGFloat, segments: Int = 48) -> [CGPoint]? {
        guard let toImage = courtToImage, let middle = courtPoint(forImage: center) else { return nil }
        let referenceDepth = toImage.depth(middle)
        var points: [CGPoint] = []
        for step in 0..<segments {
            let angle = Double(step) / Double(segments) * 2 * Double.pi
            let onFloor = CGPoint(
                x: middle.x + diameter / 2 * CGFloat(cos(angle)),
                y: middle.y + diameter / 2 * CGFloat(sin(angle))
            )
            // A point past the horizon would flip to the wrong side of the picture.
            guard toImage.depth(onFloor) * referenceDepth > 0, let mapped = toImage.map(onFloor) else { return nil }
            points.append(mapped)
        }
        return points
    }

    /// A default four-sided shape to start dragging from, roughly where a court sits in view.
    public static func startingCorners() -> [CGPoint] {
        [CGPoint(x: 0.35, y: 0.45), CGPoint(x: 0.65, y: 0.45), CGPoint(x: 0.85, y: 0.85), CGPoint(x: 0.15, y: 0.85)]
    }
}
