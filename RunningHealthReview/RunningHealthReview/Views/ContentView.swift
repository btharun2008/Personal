import SwiftUI

struct ContentView: View {
    @StateObject private var healthKit = HealthKitManager()
    @State private var showingSettings = false
    @State private var showingTrendAnalysis = false
    @State private var trendAnalysis: String = ""
    @State private var isFetchingTrend = false
    @State private var trendError: String?

    var body: some View {
        NavigationStack {
            Group {
                if !healthKit.isAuthorized {
                    PermissionView(onRequest: {
                        Task { await healthKit.requestAuthorization() }
                    })
                } else if healthKit.isLoading {
                    ProgressView("Loading runs…")
                } else if let error = healthKit.error {
                    ErrorView(message: error, onRetry: {
                        Task { await healthKit.fetchRecentWorkouts() }
                    })
                } else if healthKit.workouts.isEmpty {
                    ContentUnavailableView(
                        "No Running Workouts",
                        systemImage: "figure.run",
                        description: Text("Complete a run with Apple Health tracking to get started.")
                    )
                } else {
                    workoutList
                }
            }
            .navigationTitle("Running Review")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                if !healthKit.workouts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await fetchTrendAnalysis() }
                        } label: {
                            Label("Trend Analysis", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingTrendAnalysis) {
            AnalysisResultView(
                title: "Training Trend Analysis",
                analysis: trendAnalysis,
                isLoading: isFetchingTrend,
                error: trendError
            )
        }
    }

    // MARK: - Workout List

    private var workoutList: some View {
        List(healthKit.workouts) { workout in
            NavigationLink {
                WorkoutDetailView(workout: workout, history: healthKit.workouts)
            } label: {
                WorkoutRowView(workout: workout)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await healthKit.fetchRecentWorkouts()
        }
    }

    // MARK: - Trend Analysis

    private func fetchTrendAnalysis() async {
        isFetchingTrend = true
        trendError = nil
        trendAnalysis = ""
        showingTrendAnalysis = true
        do {
            trendAnalysis = try await ClaudeService.shared.analyseWorkouts(healthKit.workouts)
        } catch {
            trendError = error.localizedDescription
        }
        isFetchingTrend = false
    }
}

// MARK: - Permission View

struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            Text("Running Health Review")
                .font(.title).bold()
            Text("This app reads your running workouts from Apple Health and uses AI to give you personalised coaching advice.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: onRequest) {
                Label("Connect Apple Health", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.red)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Try Again", action: onRetry).buttonStyle(.bordered)
        }
        .padding()
    }
}
