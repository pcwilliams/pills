# Pills

A minimal iOS app for tracking daily morning and evening medication, built entirely through conversation with [Claude Code](https://claude.ai/claude-code).

<p align="center">
  <img src="pillsapp3.jpg" width="300" alt="Pills app running on iPhone 16 Pro" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue" alt="iOS 17+" />
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-cyan" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/storage-SwiftData-purple" alt="SwiftData" />
  <img src="https://img.shields.io/badge/dependencies-0-brightgreen" alt="Zero dependencies" />
</p>

## Features

- **Month calendar view** with navigable history (swipe or tap arrows)
- **Cyan bar** for morning pills, **orange bar** for evening pills on each day
- **Tap to mark as taken** (turns grey) &mdash; tap again to undo
- **History lock** &mdash; past days are locked by default to prevent accidental edits; unlock via the lock icon or when prompted, with automatic relock after 10 minutes
- **Visual states** &mdash; today's bars are vivid; past missed and future days are dimmed; past taken days show dimmed grey
- **Streak counter** &mdash; tracks consecutive days where both pills were taken
- **Haptic feedback** on every tap
- **Animated transitions** between months with directional slide
- **Notification reminders** &mdash; configurable morning and evening reminders via local notifications; automatically cancelled when pills are marked as taken

![Evening pill reminder notification](reminder.jpg)

- **Settings page** &mdash; gear icon opens settings to configure notification times, enable/disable reminders, and toggle the history lock
- **Persistent storage** via SwiftData &mdash; survives app restarts
- **Dark-mode app icon** styled after the in-app day cell

## Getting Started

1. Clone this repo
2. Open `Pills.xcodeproj` in Xcode 16+
3. Select the **Pills** target &rarr; **Signing & Capabilities**
4. Set your **Development Team** (Apple ID)
5. Choose your iPhone or a simulator as the run destination
6. Press **Cmd+R** to build and run

## How It Works

Each day in the calendar displays two horizontal bars:

| Bar | Colour | Meaning |
|---|---|---|
| Top | Cyan | Morning pills |
| Bottom | Orange | Evening pills |
| Either | Grey | Taken (tapped) |

- **Today** &mdash; Bars are full colour. Taken bars turn solid grey. Tap to toggle.
- **Past days** &mdash; Untaken bars appear dimmed. Taken bars are dimmed grey. Tappable to correct mistakes, but history is locked by default &mdash; tapping a past day prompts to unlock (auto-relocks after 10 minutes).
- **Future days** &mdash; Bars appear dimmed. Not tappable.

The streak counter appears when you have one or more consecutive days with both pills taken. It counts backwards from today (or yesterday if today isn't yet complete).

## Project Structure

```
Pills/
├── PillsApp.swift           # App entry point with SwiftData container
├── ContentView.swift        # Main view: navigation, streak, calendar, legend
├── Models/
│   └── PillRecord.swift     # Data model (date, morningTaken, eveningTaken)
├── Views/
│   ├── CalendarView.swift   # Month grid layout using GeometryReader
│   ├── DayCellView.swift    # Individual day cell with pill bars
│   ├── StreakView.swift     # Streak counter display
│   └── SettingsView.swift   # Settings sheet: notifications, history lock
├── Services/
│   └── NotificationManager.swift  # Local notification scheduling & management
└── Assets.xcassets/
    └── AppIcon.appiconset/  # Dark-mode 1024x1024 app icon
PillsTests/
└── PillsTests.swift         # 49 unit tests
```

## Documentation

This project includes rich HTML documentation best viewed locally in a browser:

- **[architecture.html](architecture.html)** &mdash; Architecture & design docs with interactive Mermaid.js diagrams: view hierarchy, data model, data flow, calendar layout strategy, and streak algorithm
- **[tutorial.html](tutorial.html)** &mdash; Step-by-step tutorial showing how this entire app was built through conversation with Claude Code, including the prompts used, design decisions, and iterative refinements

> To view: clone the repo and open the HTML files in your browser, or use a local server.

## Build from Command Line

```bash
xcodebuild -project Pills.xcodeproj -scheme Pills \
  -destination 'generic/platform=iOS' build \
  CODE_SIGNING_ALLOWED=NO
```

## Run Tests

```bash
xcodebuild -project Pills.xcodeproj -scheme Pills \
  -destination 'platform=iOS Simulator,name=iPhone 16' test \
  CODE_SIGNING_ALLOWED=NO
```

49 unit tests cover all user-triggered data updates (toggle on/off, field independence, double-toggle round-trips, date-matching, SwiftData persistence, streak calculation edge cases) and notification logic (scheduling decisions, cancellation ID generation, foreground suppression). Tests use an in-memory SwiftData container for isolation and speed.

## How This Was Built

This app was built entirely through a single conversation with Claude Code &mdash; from the initial idea through to the finished app running on an iPhone 16 Pro. The [tutorial](tutorial.html) documents every prompt and response. Key stats:

| | |
|---|---|
| **Prompts** | 13 |
| **UI refinement rounds** | 4 |
| **External dependencies** | 0 |
| **Lines of Swift** | ~700 |
| **Unit tests** | 49 |
| **Conversations** | 2 |

## License

Personal use.
