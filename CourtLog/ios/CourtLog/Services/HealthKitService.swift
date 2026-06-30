import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let store = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit 不可用"
            return
        }

        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
        } catch {
            authorizationError = error.localizedDescription
        }
    }

    /// Start tennis workout — requires Watch companion or phone-only workout in v0.2.
    func startWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .tennis
        config.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        workoutSession = session
        self.builder = builder

        session.startActivity(with: .now)
        try await builder.beginCollection(at: .now)
    }

    func endWorkout() async throws -> HealthSummary {
        guard let session = workoutSession, let builder = builder else {
            return HealthSummary()
        }

        let end = Date()
        try await builder.endCollection(at: end)
        try await builder.finishWorkout()
        session.end()

        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        let avgHR = try await averageQuantity(for: hrType, unit: .count().unitDivided(by: .minute()))
        let energy = try await sumQuantity(for: energyType, unit: .kilocalorie())

        workoutSession = nil
        self.builder = nil

        return HealthSummary(
            avgHeartRate: avgHR,
            activeCalories: energy,
            durationSec: end.timeIntervalSince(session.startDate ?? end)
        )
    }

    private func averageQuantity(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        // Placeholder — query statistics from builder in production
        nil
    }

    private func sumQuantity(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        nil
    }
}

struct HealthSummary {
    var avgHeartRate: Double?
    var activeCalories: Double?
    var durationSec: Double?
}
