import CoreGraphics

/// How a player's floor halo is drawn, shared by the app and the track-video tool
/// so both look the same.
public enum HaloStyle {
    /// Halo width as a share of the player's height in the image.
    public static let widthShareOfPlayerHeight: CGFloat = 0.48
    /// The halo is a flat ellipse, as if lying on the floor: height as a share of width.
    public static let heightShareOfWidth: CGFloat = 0.3
    /// The smallest halo, in screen points, so far-away players still get a visible ring.
    public static let minimumWidth: CGFloat = 19
    /// With a court calibration, the halo is a true circle on the floor this many metres across.
    public static let floorDiameter: CGFloat = 0.8

    /// The halo's rectangle, centred on `center`, for a player `playerHeight` tall (both in the same units).
    public static func ring(center: CGPoint, playerHeight: CGFloat, minimumWidth: CGFloat = minimumWidth) -> CGRect {
        let width = max(playerHeight * widthShareOfPlayerHeight, minimumWidth)
        let height = width * heightShareOfWidth
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
