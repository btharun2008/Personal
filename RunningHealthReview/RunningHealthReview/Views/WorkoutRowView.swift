import SwiftUI

struct WorkoutRowView: View {
    let workout: RunWorkout

    private var dateText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: workout.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                statView(icon: "figure.run", value: workout.formattedDistance)
                statView(icon: "clock", value: workout.formattedDuration)
                statView(icon: "speedometer", value: workout.formattedPace)
                if let hr = workout.heartRateAvg {
                    statView(icon: "heart.fill", value: "\(Int(hr)) bpm")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statView(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(.orange)
            Text(value).font(.callout.monospacedDigit())
        }
    }
}
