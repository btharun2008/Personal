import Foundation

enum ClaudeError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case decodingError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:    return "No API key set. Go to Settings and add your Anthropic API key."
        case .networkError(let m): return "Network error: \(m)"
        case .decodingError(let m): return "Unexpected response: \(m)"
        case .apiError(let m):  return "Claude error: \(m)"
        }
    }
}

// MARK: - Response model

private struct ClaudeResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }
    struct ErrorBody: Decodable {
        struct Inner: Decodable { let message: String }
        let error: Inner
    }
    let content: [Content]?
    let type: String?
}

// MARK: - Service

final class ClaudeService {

    static let shared = ClaudeService()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-6"

    // MARK: - Analyse multiple workouts (trend analysis)

    func analyseWorkouts(_ workouts: [RunWorkout]) async throws -> String {
        let prompt = buildTrendPrompt(workouts)
        return try await sendMessage(prompt)
    }

    // MARK: - Analyse single workout

    func analyseWorkout(_ workout: RunWorkout, history: [RunWorkout]) async throws -> String {
        let prompt = buildSingleRunPrompt(workout, history: history)
        return try await sendMessage(prompt)
    }

    // MARK: - API call

    private func sendMessage(_ userContent: String) async throws -> String {
        let apiKey = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        guard !apiKey.isEmpty else { throw ClaudeError.invalidAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "thinking": ["type": "adaptive"],
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(ClaudeResponse.ErrorBody.self, from: data))?.error.message
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw ClaudeError.apiError(msg)
        }

        guard let decoded = try? JSONDecoder().decode(ClaudeResponse.self, from: data),
              let text = decoded.content?.first(where: { $0.type == "text" })?.text
        else {
            throw ClaudeError.decodingError("Could not parse Claude response.")
        }
        return text
    }

    // MARK: - Prompt builders

    private func buildSingleRunPrompt(_ workout: RunWorkout, history: [RunWorkout]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var prompt = """
        You are an expert running coach. Analyse this run and provide specific, actionable coaching advice.

        ## Today's Run
        - Date: \(dateFormatter.string(from: workout.startDate))
        - Distance: \(workout.formattedDistance)
        - Duration: \(workout.formattedDuration)
        - Average Pace: \(workout.formattedPace)
        - Calories: \(workout.calories.map { String(format: "%.0f kcal", $0) } ?? "N/A")
        - Elevation Gain: \(workout.elevationGain.map { String(format: "%.0f m", $0) } ?? "N/A")
        """

        if let avg = workout.heartRateAvg, let min = workout.heartRateMin, let max = workout.heartRateMax {
            prompt += """

        - Avg Heart Rate: \(Int(avg)) bpm
        - Min Heart Rate: \(Int(min)) bpm
        - Max Heart Rate: \(Int(max)) bpm
        """
        }

        if !workout.heartRateSamples.isEmpty {
            let zones = heartRateZoneDistribution(workout.heartRateSamples)
            prompt += "\n- Heart Rate Zones: \(zones)"
        }

        if !history.isEmpty {
            prompt += "\n\n## Recent Training History (last \(history.count) runs)\n"
            for (i, run) in history.prefix(5).enumerated() {
                prompt += "\(i + 1). \(dateFormatter.string(from: run.startDate)) — \(run.formattedDistance) in \(run.formattedDuration) @ \(run.formattedPace)"
                if let hr = run.heartRateAvg { prompt += ", avg HR \(Int(hr)) bpm" }
                prompt += "\n"
            }
        }

        prompt += """

        Please provide a structured coaching report with:
        1. **Run Summary**: Brief assessment of this run's quality
        2. **Pacing Analysis**: Was the effort well-distributed? Too fast/slow?
        3. **Heart Rate Analysis**: Which zones were targeted, and is that appropriate?
        4. **Compared to Recent Runs**: Progress or regression vs history
        5. **Top 3 Improvement Tips**: Specific, actionable advice for the next run
        6. **Suggested Next Workout**: A concrete recommendation for the next session
        """
        return prompt
    }

    private func buildTrendPrompt(_ workouts: [RunWorkout]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var prompt = """
        You are an expert running coach. Analyse these \(workouts.count) recent running workouts and provide a comprehensive training review.

        ## Running Workout History (most recent first)
        """

        for (i, workout) in workouts.enumerated() {
            prompt += "\n\n### Run \(i + 1) — \(dateFormatter.string(from: workout.startDate))"
            prompt += "\n- Distance: \(workout.formattedDistance)"
            prompt += "\n- Duration: \(workout.formattedDuration)"
            prompt += "\n- Pace: \(workout.formattedPace)"
            if let hr = workout.heartRateAvg { prompt += "\n- Avg HR: \(Int(hr)) bpm" }
            if let max = workout.heartRateMax { prompt += " (max \(Int(max)) bpm)" }
            if let cal = workout.calories { prompt += "\n- Calories: \(Int(cal)) kcal" }
            if let elev = workout.elevationGain { prompt += "\n- Elevation: +\(Int(elev)) m" }
        }

        prompt += """


        Please provide a comprehensive training review with:
        1. **Overall Progress**: Trends in distance, pace, and fitness over these runs
        2. **Training Load Assessment**: Is the volume and intensity appropriate? Signs of over/under-training?
        3. **Pacing Patterns**: Are runs consistently paced? Any problematic patterns?
        4. **Heart Rate Trends**: Are zones appropriate for the stated goals?
        5. **Strengths**: What is going well in this training?
        6. **Top 5 Improvement Areas**: Prioritised, specific, actionable recommendations
        7. **Suggested 2-Week Training Plan**: A simple plan tailored to these patterns
        """
        return prompt
    }

    // MARK: - Heart Rate Zone Helper

    private func heartRateZoneDistribution(_ samples: [HeartRateSample]) -> String {
        guard !samples.isEmpty else { return "N/A" }
        // Approximate zones based on % of 220-age (using generic 180 max for unknown age)
        let maxHR = 180.0
        var zones = [0, 0, 0, 0, 0] // Z1-Z5 counts
        for sample in samples {
            let pct = sample.bpm / maxHR
            switch pct {
            case ..<0.60: zones[0] += 1
            case 0.60..<0.70: zones[1] += 1
            case 0.70..<0.80: zones[2] += 1
            case 0.80..<0.90: zones[3] += 1
            default: zones[4] += 1
            }
        }
        let total = Double(samples.count)
        let pcts = zones.map { Int(Double($0) / total * 100) }
        return "Z1:\(pcts[0])% Z2:\(pcts[1])% Z3:\(pcts[2])% Z4:\(pcts[3])% Z5:\(pcts[4])%"
    }
}
