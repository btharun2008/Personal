# Running Health Review

An iOS app that reads your running workouts live from Apple Health and uses Claude AI to give you personalised coaching advice.

## Features

- **Live HealthKit integration** — reads runs directly from Apple Health, no export needed
- **Per-run AI coaching** — pacing analysis, heart rate zones, improvement tips from Claude Opus 4.6
- **Training trend analysis** — big-picture review across all recent runs + a 2-week training plan
- **Heart rate chart** — visual HR trace (Swift Charts) for every run
- **Share reports** — export AI coaching text via iOS share sheet

---

## Install on iPhone — No Mac required

This setup uses **Codemagic** (free cloud builds) + **SideStore** (free sideloading, no computer needed).

### Step 1 — Get a free Apple ID

If you don't have one: [appleid.apple.com](https://appleid.apple.com). A regular free Apple ID works.

### Step 2 — Install SideStore on your iPhone

SideStore is a free app that lets you install unsigned apps (IPA files) without a computer.

1. On your iPhone, open Safari and go to **[sidestore.io](https://sidestore.io)**
2. Follow their installation guide (takes about 10 minutes, involves a trusted certificate)
3. Once installed, SideStore lives on your home screen

> SideStore re-signs apps automatically every 7 days using your Apple ID — you just need the app open once a week while on WiFi.

### Step 3 — Create a Codemagic account

1. Go to [codemagic.io](https://codemagic.io) and sign up free (500 build minutes/month included)
2. Connect your GitHub account when prompted

### Step 4 — Fork this repo to your GitHub

1. Go to the GitHub repo for this project
2. Click **Fork** (top-right)

### Step 5 — Add your Apple credentials to Codemagic

1. In Codemagic dashboard → **Teams** → **Personal Account** → **Integrations**
2. Click **Connect** next to Apple Developer Portal
3. Sign in with your free Apple ID
4. Codemagic will create a development certificate and provisioning profile automatically

### Step 6 — Set environment variables in Codemagic

In your app's settings → **Environment variables**, add:

| Variable | Value |
|----------|-------|
| `ANTHROPIC_API_KEY` | Your key from [console.anthropic.com](https://console.anthropic.com) |
| `NOTIFICATION_EMAIL` | Your email (to receive the built IPA) |

> The API key is stored securely in Codemagic and embedded in the app at build time.

### Step 7 — Trigger a build

1. In Codemagic, click your forked repo → **Start new build**
2. Select the `ios-development` workflow → **Start build**
3. The build takes ~10–15 minutes
4. When done, you'll receive an email with a download link for the `.ipa` file

### Step 8 — Install the IPA on your iPhone

1. Download the `.ipa` file to your iPhone (tap the email link, save to Files app)
2. Open **SideStore** → tap **+** → select the `.ipa` from Files
3. The app installs immediately
4. Go to **Settings → General → VPN & Device Management** and trust the certificate

### Step 9 — Add your API key

1. Open the app → tap the **gear icon** (Settings)
2. Paste your Anthropic API key
3. Start reviewing your runs!

---

## Rebuilding / Updates

When you want to update the app:

1. Push changes to the `main` branch of your GitHub fork
2. Codemagic automatically triggers a new build
3. Download the new IPA and reinstall via SideStore (SideStore will update in-place)

---

## Project structure

```
├── RunningHealthReview/          iOS app
│   ├── project.yml               XcodeGen project definition
│   ├── exportOptions.plist       IPA export settings
│   └── RunningHealthReview/      Swift source files
│       ├── RunningHealthReviewApp.swift
│       ├── Models/
│       │   └── RunWorkout.swift
│       ├── Services/
│       │   ├── HealthKitManager.swift  ← reads Apple Health
│       │   └── ClaudeService.swift     ← calls Claude API
│       └── Views/
│           ├── ContentView.swift
│           ├── WorkoutRowView.swift
│           ├── WorkoutDetailView.swift
│           ├── AnalysisResultView.swift
│           └── SettingsView.swift
├── codemagic.yaml                Cloud build configuration
└── web/                          Optional Python web app (alternative)
```

---

## How it works

1. On first launch the app requests HealthKit read access for workouts, heart rate, and calories
2. Your 20 most recent running workouts are fetched live from Apple Health
3. Tapping a run sends workout stats to **Claude Opus 4.6** via the Anthropic API
4. Claude analyses pacing, heart rate zones, and your training history
5. The **Trend Analysis** button sends all loaded workouts for a broader review + training plan

---

## Requirements

- iPhone running iOS 17+
- Free Apple ID
- Free Codemagic account
- Anthropic API key ([console.anthropic.com](https://console.anthropic.com))
