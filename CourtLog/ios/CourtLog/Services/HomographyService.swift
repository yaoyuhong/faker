import Foundation

/// DLT homography: 4 point correspondences (image ↔ court plane, meters).
enum HomographyService {
    /// 3×3 homography (row-major, h₈ = 1) mapping image pixels → court meters.
    static func compute(
        imagePoints: [CodablePoint],
        courtPoints: [CodablePoint]
    ) -> [Double]? {
        guard imagePoints.count == 4, courtPoints.count == 4 else { return nil }

        // 8×8 system with h₈ fixed to 1
        var a = [Double](repeating: 0, count: 64)
        var b = [Double](repeating: 0, count: 8)

        for i in 0..<4 {
            let u = imagePoints[i].x
            let v = imagePoints[i].y
            let x = courtPoints[i].x
            let y = courtPoints[i].y
            let r0 = i * 2
            let r1 = r0 + 1

            a[r0 * 8 + 0] = u
            a[r0 * 8 + 1] = v
            a[r0 * 8 + 2] = 1
            a[r0 * 8 + 6] = -u * x
            a[r0 * 8 + 7] = -v * x
            b[r0] = x

            a[r1 * 8 + 3] = u
            a[r1 * 8 + 4] = v
            a[r1 * 8 + 5] = 1
            a[r1 * 8 + 6] = -u * y
            a[r1 * 8 + 7] = -v * y
            b[r1] = y
        }

        guard let h7 = solveLinearSystem8(a: a, b: b) else { return nil }
        return h7 + [1.0]
    }

    static func mapPoint(_ pixel: CodablePoint, homography h: [Double]) -> CodablePoint? {
        guard h.count == 9 else { return nil }
        let x = h[0] * pixel.x + h[1] * pixel.y + h[2]
        let y = h[3] * pixel.x + h[4] * pixel.y + h[5]
        let w = h[6] * pixel.x + h[7] * pixel.y + h[8]
        guard abs(w) > 1e-9 else { return nil }
        return CodablePoint(x: x / w, y: y / w)
    }

  /// Gaussian elimination for 8×8.
    private static func solveLinearSystem8(a: [Double], b: [Double]) -> [Double]? {
        var m = a
        var rhs = b
        let n = 8

        for col in 0..<n {
            var pivot = col
            for row in (col + 1)..<n {
                if abs(m[row * n + col]) > abs(m[pivot * n + col]) {
                    pivot = row
                }
            }
            if abs(m[pivot * n + col]) < 1e-12 { return nil }

            if pivot != col {
                for k in 0..<n {
                    m.swapAt(col * n + k, pivot * n + k)
                }
                rhs.swapAt(col, pivot)
            }

            let div = m[col * n + col]
            for k in col..<n { m[col * n + k] /= div }
            rhs[col] /= div

            for row in 0..<n where row != col {
                let factor = m[row * n + col]
                if factor == 0 { continue }
                for k in col..<n {
                    m[row * n + k] -= factor * m[col * n + k]
                }
                rhs[row] -= factor * rhs[col]
            }
        }
        return rhs
    }
}
