import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var durationSec: Double
    var videoFileName: String?
    var uploadState: UploadState
    var analysisState: AnalysisState

    // Calibration: 4 image points + 4 court points (meters)
    var calibrationImagePoints: [CodablePoint]
    var calibrationCourtPoints: [CodablePoint]

    // Health summary from Apple Watch / HealthKit
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeCalories: Double?

    // Cached analysis (decoded from API)
    var analysisJSON: Data?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        durationSec: Double = 0,
        videoFileName: String? = nil,
        uploadState: UploadState = .pending,
        analysisState: AnalysisState = .none,
        calibrationImagePoints: [CodablePoint] = [],
        calibrationCourtPoints: [CodablePoint] = CourtGeometry.defaultCornersMeters
    ) {
        self.id = id
        self.createdAt = createdAt
        self.durationSec = durationSec
        self.videoFileName = videoFileName
        self.uploadState = uploadState
        self.analysisState = analysisState
        self.calibrationImagePoints = calibrationImagePoints
        self.calibrationCourtPoints = calibrationCourtPoints
    }
}

enum UploadState: String, Codable {
    case pending, uploading, uploaded, failed
}

enum AnalysisState: String, Codable {
    case none, pending, running, done, failed
}

struct CodablePoint: Codable, Hashable {
    var x: Double
    var y: Double
}

/// Standard singles court corners in meters (origin = near-left doubles sideline / baseline).
enum CourtGeometry {
    static let singlesWidth = 8.23
    static let singlesLength = 23.77

    static var defaultCornersMeters: [CodablePoint] {
        [
            CodablePoint(x: 0, y: 0),
            CodablePoint(x: singlesWidth, y: 0),
            CodablePoint(x: singlesWidth, y: singlesLength),
            CodablePoint(x: 0, y: singlesLength)
        ]
    }
}

struct AnalysisResult: Codable {
    var ballPositions: [BallPosition]
    var bounces: [Bounce]
    var heatmap: Heatmap
    var maxSpeedKmh: Double
    var avgSpeedKmh: Double
    var previewUrl: String?
}

struct BallPosition: Codable {
    var t: Double
    var x: Double
    var y: Double
}

struct Bounce: Codable {
    var t: Double
    var x: Double
    var y: Double
    var `in`: Bool
    var speedKmh: Double
}

struct Heatmap: Codable {
    var grid: Int
    var counts: [[Int]]
}
