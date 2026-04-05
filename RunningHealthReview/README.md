# Running Health Review

An iOS app that reads your running workouts from Apple Health and uses Claude AI to provide personalised coaching advice.

## Features

- **Workout List** — Browse your recent runs with distance, duration, pace, and heart rate
- **Run Analysis** — Tap any run for detailed AI coaching: pacing, heart rate zones, and specific tips
- **Trend Analysis** — Get a big-picture review of your recent training, plus a 2-week plan
- **Heart Rate Chart** — Visual HR trace for each run
- **Share** — Export AI reports via the iOS share sheet

## Setup in Xcode

### 1. Create the Xcode project

1. Open Xcode → **File > New > Project**
2. Choose **iOS > App**
3. Set:
   - Product Name: `RunningHealthReview`
   - Team: your Apple Developer account
   - Bundle Identifier: `com.yourname.RunningHealthReview`
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save the project

### 2. Add source files

Delete the default `ContentView.swift` that Xcode creates, then drag all `.swift` files from this folder into the project navigator, keeping the same folder structure.

### 3. Enable HealthKit

1. Select your project in the navigator
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** → add **HealthKit**
4. Check **Clinical Health Records** if you want (not required)

### 4. Replace Info.plist keys

Open `Info.plist` in Xcode and ensure these keys are present (they're in the provided file):
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

### 5. Add your Anthropic API key

1. Build and run on your iPhone (simulator won't have health data)
2. Tap the **gear icon** → Settings
3. Paste your API key from [console.anthropic.com](https://console.anthropic.com)

The key is stored in `@AppStorage` (UserDefaults) locally on your device.

## Project Structure

```
RunningHealthReview/
├── RunningHealthReviewApp.swift      # App entry point
├── Models/
│   └── RunWorkout.swift              # Workout data model
├── Services/
│   ├── HealthKitManager.swift        # HealthKit queries
│   └── ClaudeService.swift           # Claude API integration
├── Views/
│   ├── ContentView.swift             # Root view + workout list
│   ├── WorkoutRowView.swift          # List row
│   ├── WorkoutDetailView.swift       # Run detail + AI analysis
│   ├── AnalysisResultView.swift      # Trend analysis sheet
│   └── SettingsView.swift            # API key settings
└── Info.plist                        # HealthKit permissions
```

## How it works

1. On first launch, the app requests HealthKit read access for workouts, heart rate, and calories
2. Your 20 most recent running workouts are fetched from Apple Health
3. Tapping a run sends workout stats to Claude Opus 4.6 via the Anthropic API
4. Claude analyses pacing, heart rate zones, and training history to generate coaching advice
5. The "Trend Analysis" button sends all loaded workouts for a broader training review

## Requirements

- iOS 17+
- Xcode 15+
- Apple Developer account (free works for personal device testing)
- Anthropic API key
