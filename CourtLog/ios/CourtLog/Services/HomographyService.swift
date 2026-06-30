import Foundation
import Accelerate

/// Computes homography from 4 point correspondences (image ↔ court plane).
/// Uses DLT (Direct Linear Transform). For production, consider OpenCV wrapper.
enum HomographyService {
    /// Map image pixel to court meters using 3×3 homography matrix H.
    static func compute(
        imagePoints: [CodablePoint],
        courtPoints: [CodablePoint]
    ) -> [Double]? {
        guard imagePoints.count == 4, courtPoints.count == 4 else { return nil }

        // Build Ah = 0 system for DLT (8 equations, 9 unknowns)
        var a = [Double](repeating: 0, count: 72) // 8 x 9
        for i in 0..<4 {
            let u = imagePoints[i].x
            let v = imagePoints[i].y
            let x = courtPoints[i].x
            let y = courtPoints[i].y
            let row = i * 2
            // x equation
            a[(row * 9) + 0] = -u
            a[(row * 9) + 1] = -v
            a[(row * 9) + 2] = -1
            a[(row * 9) + 6] = u * x
            a[(row * 9) + 7] = v * x
            a[(row * 9) + 8] = x
            // y equation
            a[((row + 1) * 9) + 3] = -u
            a[((row + 1) * 9) + 4] = -v
            a[((row + 1) * 9) + 5] = -1
            a[((row + 1) * 9) + 6] = u * y
            a[((row + 1) * 9) + 7] = v * y
            a[((row + 1) * 9) + 8] = y
        }

        // SVD via simplified power iteration placeholder — replace with vDSP/LAPACK in production
        // For MVP scaffold, return identity; real implementation uses Accelerate dgelsd
        return [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1
        ]
    }

    static func mapPoint(_ pixel: CodablePoint, homography h: [Double]) -> CodablePoint? {
        guard h.count == 9 else { return nil }
        let x = h[0] * pixel.x + h[1] * pixel.y + h[2]
        let y = h[3] * pixel.x + h[4] * pixel.y + h[5]
        let w = h[6] * pixel.x + h[7] * pixel.y + h[8]
        guard abs(w) > 1e-9 else { return nil }
        return CodablePoint(x: x / w, y: y / w)
    }
}
