import CoreGraphics
import Foundation

/// Maps points on one flat plane to another seen in perspective, such as the court floor
/// to the camera image (FR-13). Four matching points are enough to work it out.
public struct Homography: Hashable, Sendable {
    /// Row by row: [h11, h12, h13, h21, h22, h23, h31, h32, h33].
    public let matrix: [Double]

    public init(matrix: [Double]) {
        precondition(matrix.count == 9)
        self.matrix = matrix
    }

    /// Solves the mapping that takes each `from` point to the matching `to` point.
    /// Nil if the points are degenerate, for example three of them on one line.
    public init?(from source: [CGPoint], to target: [CGPoint]) {
        guard source.count == 4, target.count == 4 else { return nil }
        // For each pair: u = (h11 x + h12 y + h13) / (h31 x + h32 y + 1), and the same for v.
        // Multiplying out gives two linear equations per pair, eight in all, with h33 fixed at 1.
        var rows: [[Double]] = []
        var values: [Double] = []
        for (from, to) in zip(source, target) {
            let x = Double(from.x), y = Double(from.y), u = Double(to.x), v = Double(to.y)
            rows.append([x, y, 1, 0, 0, 0, -x * u, -y * u])
            values.append(u)
            rows.append([0, 0, 0, x, y, 1, -x * v, -y * v])
            values.append(v)
        }
        guard let solution = Self.solve(rows, values) else { return nil }
        self.init(matrix: solution + [1])
    }

    /// Where `point` lands on the other plane. Nil for points at or beyond the horizon.
    public func map(_ point: CGPoint) -> CGPoint? {
        let m = matrix
        let x = Double(point.x), y = Double(point.y)
        let w = m[6] * x + m[7] * y + m[8]
        guard abs(w) > 1e-12 else { return nil }
        return CGPoint(x: (m[0] * x + m[1] * y + m[2]) / w, y: (m[3] * x + m[4] * y + m[5]) / w)
    }

    /// The scale factor `w` for a point. Points on the visible side all share one sign.
    func depth(_ point: CGPoint) -> Double {
        matrix[6] * Double(point.x) + matrix[7] * Double(point.y) + matrix[8]
    }

    /// The mapping the other way. Nil if it cannot be undone.
    public var inverted: Homography? {
        let m = matrix
        let cofactors = [
            m[4] * m[8] - m[5] * m[7], m[2] * m[7] - m[1] * m[8], m[1] * m[5] - m[2] * m[4],
            m[5] * m[6] - m[3] * m[8], m[0] * m[8] - m[2] * m[6], m[2] * m[3] - m[0] * m[5],
            m[3] * m[7] - m[4] * m[6], m[1] * m[6] - m[0] * m[7], m[0] * m[4] - m[1] * m[3],
        ]
        let determinant = m[0] * cofactors[0] + m[1] * cofactors[3] + m[2] * cofactors[6]
        guard abs(determinant) > 1e-12 else { return nil }
        return Homography(matrix: cofactors.map { $0 / determinant })
    }

    /// Gaussian elimination with partial pivoting. Small and fixed in size, so plain code is fine.
    private static func solve(_ rows: [[Double]], _ values: [Double]) -> [Double]? {
        let size = values.count
        var a = rows.enumerated().map { $0.element + [values[$0.offset]] }
        for column in 0..<size {
            guard let pivot = (column..<size).max(by: { abs(a[$0][column]) < abs(a[$1][column]) }),
                  abs(a[pivot][column]) > 1e-12 else { return nil }
            a.swapAt(column, pivot)
            for row in 0..<size where row != column {
                let factor = a[row][column] / a[column][column]
                guard factor != 0 else { continue }
                for k in column...size {
                    a[row][k] -= factor * a[column][k]
                }
            }
        }
        return (0..<size).map { a[$0][size] / a[$0][$0] }
    }
}
