import Observation
import SwiftUI

/// The latest tracking result, for drawing on the camera view.
@Observable
final class TrackingOverlay {
    private(set) var frame: TrackingFrame?

    func show(_ frame: TrackingFrame) {
        self.frame = frame
    }

    func clear() {
        frame = nil
    }
}

/// Draws floor halos under players and a circle with a trail on the shuttle (FR-27).
/// Drawn on screen only. Recordings stay clean for training.
struct TrackingOverlayView: View {
    let frame: TrackingFrame

    var body: some View {
        Canvas { context, size in
            let mapper = Mapper(viewSize: size, imageAspect: frame.imageAspect)

            for player in frame.players {
                // A flat ellipse, as if lying on the floor. Without court calibration
                // it cannot follow true perspective yet.
                let center = mapper.point(player.center)
                let width = max(player.size * mapper.imageHeight * 0.6, 24)
                let height = width * 0.3
                let ring = Path(ellipseIn: CGRect(
                    x: center.x - width / 2, y: center.y - height / 2, width: width, height: height
                ))
                context.fill(ring, with: .color(.cyan.opacity(0.18)))
                context.stroke(ring, with: .color(.cyan), lineWidth: 3)
            }

            let trail = frame.trail.map(mapper.point)
            for index in trail.indices.dropFirst() {
                var segment = Path()
                segment.move(to: trail[index - 1])
                segment.addLine(to: trail[index])
                let fade = Double(index) / Double(trail.count)
                context.stroke(segment, with: .color(.yellow.opacity(fade)), lineWidth: 2 + 3 * fade)
            }

            if let shuttle = frame.shuttle {
                let point = mapper.point(shuttle)
                let circle = Path(ellipseIn: CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32))
                context.stroke(circle, with: .color(.yellow), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Matches the preview, which fills the view and crops the image edges (aspect fill).
    private struct Mapper {
        let origin: CGPoint
        let imageWidth: CGFloat
        let imageHeight: CGFloat

        init(viewSize: CGSize, imageAspect: CGFloat) {
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

        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + normalized.x * imageWidth, y: origin.y + normalized.y * imageHeight)
        }
    }
}
