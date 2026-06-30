import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let store = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var sessionStart: Date?

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

    func startWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .tennis
        config.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        workoutSession = session
        self.builder = builder
        sessionStart = .now

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

        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let avgHR = builder.statistics(for: hrType)?
            .averageQuantity()?
            .doubleValue(for: hrUnit)

        let maxHR = builder.statistics(for: hrType)?
            .maximumQuantity()?
            .doubleValue(for: hrUnit)

        let energy = builder.statistics(for: energyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        let start = sessionStart ?? session.startDate ?? end
        workoutSession = nil
        self.builder = nil
        sessionStart = nil

        return HealthSummary(
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            activeCalories: energy,
            durationSec: end.timeIntervalSince(start)
        )
    }
}

struct HealthSummary {
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeCalories: Double?
    var durationSec: Double?
}
