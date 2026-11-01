import Observation
import SwiftUI
import TrackingKit

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
/// With a court calibration, halos are true circles on the floor and the court outline shows.
/// Drawn on screen only. Recordings stay clean for training.
struct TrackingOverlayView: View {
    let frame: TrackingFrame
    let calibration: CourtCalibration?

    var body: some View {
        Canvas { context, size in
            let mapper = AspectFillMapper(viewSize: size, imageAspect: frame.imageAspect)
            let court = calibration.flatMap { $0.isValid && $0.fits(imageAspect: frame.imageAspect) ? $0 : nil }

            if let court {
                var outline = Path()
                outline.addLines(court.imageCorners.map(mapper.viewPoint))
                outline.closeSubpath()
                context.stroke(outline, with: .color(.white.opacity(0.4)), lineWidth: 2)
            }

            for player in frame.players {
                let ring: Path
                if let court, let points = court.floorRing(aroundImagePoint: player.center, diameter: HaloStyle.floorDiameter) {
                    // A real circle on the floor, seen in perspective.
                    var path = Path()
                    path.addLines(points.map(mapper.viewPoint))
                    path.closeSubpath()
                    ring = path
                } else {
                    // Without a calibration, a flat ellipse stands in for the floor circle.
                    ring = Path(ellipseIn: HaloStyle.ring(
                        center: mapper.viewPoint(player.center),
                        playerHeight: player.size * mapper.imageHeight
                    ))
                }
                context.fill(ring, with: .color(.cyan.opacity(0.18)))
                context.stroke(ring, with: .color(.cyan), lineWidth: 9)
            }

            let trail = frame.trail.map(mapper.viewPoint)
            for index in trail.indices.dropFirst() {
                var segment = Path()
                segment.move(to: trail[index - 1])
                segment.addLine(to: trail[index])
                let fade = Double(index) / Double(trail.count)
                context.stroke(segment, with: .color(.yellow.opacity(fade)), lineWidth: 2 + 3 * fade)
            }

            if let shuttle = frame.shuttle {
                let point = mapper.viewPoint(shuttle)
                let circle = Path(ellipseIn: CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32))
                context.stroke(circle, with: .color(.yellow), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
