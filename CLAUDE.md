# Pills - Claude Code Project Context

## Project Overview
Pills is an iOS app for tracking daily morning and evening medication. It presents a month calendar view with tappable cyan (morning) and orange (evening) bars on each day.

## Tech Stack
- **Language:** Swift 5
- **UI Framework:** SwiftUI
- **Persistence:** SwiftData
- **Minimum Target:** iOS 17.0
- **Device:** iPhone only (TARGETED_DEVICE_FAMILY = 1)
- **Xcode:** 16+

## Project Structure
```
Pills/
├── Pills.xcodeproj/project.pbxproj
├── Pills/
│   ├── PillsApp.swift              # @main app entry, SwiftData container
│   ├── ContentView.swift           # Root view: header, streak, calendar, legend, history lock
│   ├── Models/
│   │   └── PillRecord.swift        # SwiftData @Model (date, morningTaken, eveningTaken)
│   ├── Views/
│   │   ├── CalendarView.swift      # Month grid with GeometryReader layout
│   │   ├── DayCellView.swift       # Day cell with pill bars and tap handling
│   │   ├── StreakView.swift        # Consecutive-day streak counter + static calculateStreak()
│   │   └── SettingsView.swift      # Settings sheet: notification toggles, time pickers, history lock
│   ├── Services/
│   │   └── NotificationManager.swift # Singleton: local notification scheduling, cancellation, delegate
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/     # Dark-mode app icon (1024x1024)
│       └── AccentColor.colorset/
├── PillsTests/
│   └── PillsTests.swift            # 49 unit tests: toggle logic, streak, persistence, notifications
├── CLAUDE.md
├── README.md
├── architecture.html               # Mermaid.js architecture diagrams
├── tutorial.html                   # Build tutorial with prompts and responses
├── pillsapp.jpg                    # Original iPhone 16 Pro screenshot
├── pillsapp2.jpg                   # Previous screenshot with lock icon
├── pillsapp3.jpg                   # Current screenshot with settings gear
└── reminder.jpg                    # Notification reminder screenshot
```

## Build & Run
```bash
# Build (skipping code signing for CI)
xcodebuild -project Pills.xcodeproj -scheme Pills -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO

# Run unit tests (requires simulator)
xcodebuild -project Pills.xcodeproj -scheme Pills -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO

# For device deployment, set DEVELOPMENT_TEAM in Xcode Signing & Capabilities
```

## Key Architecture Decisions
- **Single @Query for all records** in ContentView, filtered in code. Record count is bounded (~365/year) so this is performant and avoids dynamic predicate complexity.
- **GeometryReader in CalendarView** distributes available height across exactly 6 week rows for consistent layout regardless of month length.
- **Callbacks for toggle actions** flow from DayCellView -> CalendarView -> ContentView, where ContentView owns the modelContext and performs SwiftData inserts/updates.
- **`.id(displayedMonth)`** on CalendarView triggers SwiftUI view identity changes for animated month transitions.
- **Asymmetric slide transitions** with a tracked `slideDirection` state for natural-feeling month navigation.
- **Dark-mode app icon** generated programmatically via a Swift CoreGraphics script, styled to match the day cell design.
- **History lock via @AppStorage** stores `historyLocked` (Bool) and `unlockTimestamp` (TimeInterval) in UserDefaults. Unlocking schedules a single one-shot `DispatchWorkItem` that fires after 10 minutes to relock. On app resume, remaining time is recalculated and a fresh task is scheduled (or relocked immediately if time has elapsed). Lock state is a UI preference, not pill data, so it stays out of SwiftData.
- **Streak calculation extracted to static method** `StreakView.calculateStreak(from:)` enables unit testing of the algorithm without needing to instantiate the view.
- **Local notification reminders** via `UNUserNotificationCenter`. `NotificationManager` singleton schedules non-repeating notifications for the next 7 days, skipping periods where pills are already taken. Notifications are cancelled immediately when a pill is marked as taken, and rescheduled whenever the app becomes active. If the app is in the foreground at delivery time, the delegate suppresses already-taken notifications.
- **Settings via @AppStorage** — notification enable/disable, morning/evening reminder times, and history lock toggle all stored in UserDefaults. `SettingsView` is a modal sheet presented from a gear icon in the header.
- **ModelContainer created explicitly in PillsApp.init()** so it can be shared with `NotificationManager` for background SwiftData queries.

## Testing
- **49 unit tests** in `PillsTests/PillsTests.swift` using an in-memory SwiftData `ModelContainer`.
- Tests replicate the toggle logic from `ContentView.performToggleMorning`/`performToggleEvening` against the real `PillRecord` model.
- Coverage includes: record creation, toggle on/off, field independence, double-toggle round-trips, date-matching with time components, SwiftData persistence across contexts, all streak calculation edge cases, and notification scheduling/cancellation/suppression logic.

## Visual States for Pill Bars
| Context           | Not Taken              | Taken              |
|-------------------|------------------------|--------------------|
| Today             | Full cyan/orange       | Grey               |
| Past (missed)     | 0.3 opacity cyan/orange| Grey at 0.4 opacity|
| Future            | 0.3 opacity cyan/orange| N/A                |

- Today is always tappable (no lock check)
- Past days are tappable but guarded by history lock (locked by default; tapping shows unlock alert; unlock lasts 10 minutes)
- Future days are not tappable
- Forward month navigation is disabled beyond the current month
- Lock icon in header: `lock.fill` (locked/secondary) / `lock.open.fill` (unlocked/accent)
- Gear icon in header opens SettingsView as a modal sheet

## Notification Architecture
- **Smart cancellation pattern:** Notifications are scheduled ahead of time (7 days), then cancelled when the user marks a pill as taken. This works even when the app is not running.
- **Notification IDs:** `morning-YYYY-MM-DD` / `evening-YYYY-MM-DD` for targeted cancellation.
- **Foreground suppression:** `willPresent` delegate queries SwiftData and suppresses if pill already taken.
- **Reschedule triggers:** App becoming active (`scenePhase == .active`), toggle enable/disable, time changes.
- **Testable pure logic:** Scheduling, ID generation, and suppression decisions are extracted as `internal static` methods on `NotificationManager` (`buildSchedule`, `notificationIdentifier`, `shouldSuppressForegroundNotification`). These take all inputs as explicit parameters (no UserDefaults, no ModelContext, no UNUserNotificationCenter), making them unit-testable with injected values. `PillPeriod` enum and `PillNotification` struct are lightweight value types that decouple test assertions from `UNNotificationRequest`.

## @AppStorage Keys
| Key | Type | Default | Used By |
|-----|------|---------|---------|
| `notificationsEnabled` | Bool | false | SettingsView, NotificationManager |
| `morningReminderHour` | Int | 7 | SettingsView, NotificationManager |
| `morningReminderMinute` | Int | 0 | SettingsView, NotificationManager |
| `eveningReminderHour` | Int | 21 | SettingsView, NotificationManager |
| `eveningReminderMinute` | Int | 0 | SettingsView, NotificationManager |
| `historyLocked` | Bool | true | ContentView, SettingsView |
| `unlockTimestamp` | Double | 0 | ContentView |

## Repository
- **GitHub:** https://github.com/pcwilliams/pills

## Conventions
- No external dependencies - pure Apple frameworks only
- Portrait orientation only
- Bundle ID: com.pwilliams.Pills
- Development Team: L7GB763YG3
- **Testability:** Extract pure decision logic as `internal static` methods with explicit parameters so tests can inject values directly, avoiding singletons, UserDefaults, and system frameworks
- **Timers:** Prefer one-shot `DispatchWorkItem` over polling `Timer.publish`. Avoid always-running timers — schedule on demand, cancel on completion
- **Documentation:** Use plain Markdown syntax in `.md` files (no inline HTML). `tutorial.html` and `architecture.html` use a shared dark theme with CSS custom properties and Mermaid.js diagrams
