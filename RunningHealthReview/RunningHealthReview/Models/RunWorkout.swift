import Foundation
import HealthKit

struct RunWorkout: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distance: Double       // metres
    let duration: TimeInterval // seconds
    let calories: Double?      // kcal
    let elevationGain: Double? // metres
    let heartRateAvg: Double?  // bpm
    let heartRateMin: Double?  // bpm
    let heartRateMax: Double?  // bpm
    let heartRateSamples: [HeartRateSample]

    var distanceKm: Double { distance / 1000 }
    var distanceMiles: Double { distance / 1609.34 }

    /// Average pace in seconds per kilometre
    var paceSecsPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return duration / distanceKm
    }

    var formattedPace: String {
        let secs = paceSecsPerKm
        let mins = Int(secs) / 60
        let remainder = Int(secs) % 60
        return String(format: "%d:%02d /km", mins, remainder)
    }

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f km", distanceKm)
    }
}

struct HeartRateSample: Codable {
    let timestamp: Date
    let bpm: Double
}
