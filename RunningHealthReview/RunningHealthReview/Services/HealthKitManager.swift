import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {

    private let store = HKHealthStore()

    @Published var workouts: [RunWorkout] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAuthorized = false

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.flightsClimbed)
    ]

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "HealthKit is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchRecentWorkouts()
        } catch {
            self.error = "HealthKit authorization failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Workouts

    func fetchRecentWorkouts(limit: Int = 20) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let workoutType = HKObjectType.workoutType()
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workoutSamples: [HKWorkout]
        do {
            workoutSamples = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: runningPredicate,
                    limit: limit,
                    sortDescriptors: [sort]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
                store.execute(query)
            }
        } catch {
            self.error = "Failed to fetch workouts: \(error.localizedDescription)"
            return
        }

        var results: [RunWorkout] = []
        for hkWorkout in workoutSamples {
            let hrSamples = await fetchHeartRate(for: hkWorkout)
            let workout = RunWorkout(
                id: UUID(),
                startDate: hkWorkout.startDate,
                endDate: hkWorkout.endDate,
                distance: hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                duration: hkWorkout.duration,
                calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                elevationGain: elevationGain(from: hkWorkout),
                heartRateAvg: hrSamples.isEmpty ? nil : hrSamples.map(\.bpm).reduce(0, +) / Double(hrSamples.count),
                heartRateMin: hrSamples.map(\.bpm).min(),
                heartRateMax: hrSamples.map(\.bpm).max(),
                heartRateSamples: hrSamples
            )
            results.append(workout)
        }
        workouts = results
    }

    // MARK: - Heart Rate

    private func fetchHeartRate(for workout: HKWorkout) async -> [HeartRateSample] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let hrSamples = (samples as? [HKQuantitySample])?.map { sample in
                        HeartRateSample(
                            timestamp: sample.startDate,
                            bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        )
                    } ?? []
                    continuation.resume(returning: hrSamples)
                }
                store.execute(query)
            }
        } catch {
            return []
        }
    }

    // MARK: - Elevation

    private func elevationGain(from workout: HKWorkout) -> Double? {
        guard let stats = workout.statistics(for: HKQuantityType(.flightsClimbed)) else { return nil }
        // approximate: 1 flight ≈ 3 metres
        return (stats.sumQuantity()?.doubleValue(for: .count()) ?? 0) * 3
    }
}
