import SwiftUI
import Charts

struct WorkoutDetailView: View {
    let workout: RunWorkout
    let history: [RunWorkout]

    @State private var analysis: String = ""
    @State private var isLoading = false
    @State private var error: String?

    private var dateText: String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: workout.startDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsGrid
                if !workout.heartRateSamples.isEmpty {
                    heartRateChart
                }
                analysisSection
            }
            .padding()
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchAnalysis() }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Distance", value: workout.formattedDistance, icon: "figure.run", color: .orange)
            StatCard(title: "Duration", value: workout.formattedDuration, icon: "clock", color: .blue)
            StatCard(title: "Avg Pace", value: workout.formattedPace, icon: "speedometer", color: .green)
            if let cal = workout.calories {
                StatCard(title: "Calories", value: "\(Int(cal)) kcal", icon: "flame.fill", color: .red)
            }
            if let hrAvg = workout.heartRateAvg {
                StatCard(title: "Avg Heart Rate", value: "\(Int(hrAvg)) bpm", icon: "heart.fill", color: .pink)
            }
            if let elev = workout.elevationGain {
                StatCard(title: "Elevation", value: "+\(Int(elev)) m", icon: "mountain.2.fill", color: .brown)
            }
        }
    }

    // MARK: - Heart Rate Chart

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.pink)

            Chart(workout.heartRateSamples, id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(.pink.opacity(0.1))
            }
            .frame(height: 120)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartXAxis(.hidden)

            if let min = workout.heartRateMin, let max = workout.heartRateMax {
                HStack {
                    Text("Min: \(Int(min)) bpm").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Max: \(Int(max)) bpm").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Analysis Section

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Coaching", systemImage: "brain.head.profile")
                .font(.headline)

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Analysing your run…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let error {
                VStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .font(.callout)
                    Button("Retry") { Task { await fetchAnalysis() } }
                        .buttonStyle(.bordered)
                }
            } else if !analysis.isEmpty {
                MarkdownText(analysis)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fetch

    private func fetchAnalysis() async {
        guard analysis.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let pastRuns = history.filter { $0.id != workout.id }
            analysis = try await ClaudeService.shared.analyseWorkout(workout, history: pastRuns)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Simple Markdown renderer

struct MarkdownText: View {
    let text: String

    var body: some View {
        // SwiftUI's Text supports basic AttributedString markdown
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
                .lineSpacing(4)
        } else {
            Text(text)
                .font(.body)
                .lineSpacing(4)
        }
    }
}
