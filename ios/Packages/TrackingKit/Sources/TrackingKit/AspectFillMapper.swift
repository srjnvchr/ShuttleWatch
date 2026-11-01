import CoreGraphics

/// Converts between image points (0 to 1, origin top left) and points in a view that shows
/// the image filled edge to edge and cropped to fit, as camera previews do.
public struct AspectFillMapper: Sendable {
    public let origin: CGPoint
    /// The full image's size on screen, including the cropped-off parts.
    public let imageWidth: CGFloat
    public let imageHeight: CGFloat

    public init(viewSize: CGSize, imageAspect: CGFloat) {
        let viewAspect = viewSize.width / max(viewSize.height, 1)
        if viewAspect > imageAspect {
            imageWidth = viewSize.width
            imageHeight = viewSize.width / imageAspect
        } else {
            imageHeight = viewSize.height
            imageWidth = viewSize.height * imageAspect
        }
        origin = CGPoint(x: (viewSize.width - imageWidth) / 2, y: (viewSize.height - imageHeight) / 2)
    }

    public func viewPoint(_ normalized: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + normalized.x * imageWidth, y: origin.y + normalized.y * imageHeight)
    }

    public func imagePoint(_ view: CGPoint) -> CGPoint {
        CGPoint(x: (view.x - origin.x) / imageWidth, y: (view.y - origin.y) / imageHeight)
    }
}
