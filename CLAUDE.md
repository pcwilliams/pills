# Apple Dev - Claude Code Project Conventions

This folder contains native iOS apps built entirely through conversation with Claude Code. This file captures the shared principles, patterns, and preferences that apply across all projects.

## Tech Stack

Every project uses the same foundation:

- **Language:** Swift 5
- **UI Framework:** SwiftUI (no storyboards, no XIBs)
- **Minimum Target:** iOS 17.0+ (some projects use iOS 18.0+)
- **Xcode:** 16+
- **Device:** iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- **Orientation:** Portrait only
- **Dependencies:** Zero external dependencies — pure Apple frameworks only (SwiftUI, MapKit, CoreLocation, Photos, CryptoKit, Swift Charts, etc.)

## Architecture

All projects follow **MVVM** with SwiftUI's reactive data binding:

- **View models** are `ObservableObject` classes with `@Published` properties, observed via `@StateObject` in views
- **Views** are declarative SwiftUI — no UIKit unless wrapping a system controller (e.g. `SFSafariViewController`)
- **Services/API clients** use the `actor` pattern for thread safety
- **Networking** uses native `URLSession` with `async/await` — no external HTTP libraries
- **View models** are annotated `@MainActor` when they drive UI state

## Project Structure

Each project follows this standard layout:

```
ProjectName/
├── ProjectName.xcodeproj/
├── CLAUDE.md                    # Developer reference (this kind of file)
├── README.md                    # User-facing documentation
├── architecture.html            # Interactive Mermaid.js architecture diagrams
├── tutorial.html                # Build narrative with prompts and responses
└── ProjectName/
    ├── App/
    │   ├── ProjectNameApp.swift # @main entry point
    │   └── ContentView.swift    # Root view / navigation
    ├── Models/                  # Data model structs and SwiftData @Models
    ├── Views/                   # SwiftUI views
    │   └── Components/          # Reusable view components
    ├── Services/                # API clients, managers, business logic
    ├── ViewModels/              # ObservableObject state management
    ├── Extensions/              # Formatters and helpers
    └── Assets.xcassets/
        ├── AppIcon.appiconset/  # 1024x1024 icons (standard, dark, tinted)
        └── AccentColor.colorset/
```

Smaller projects (e.g. Where) may flatten this into fewer files — the principle is simplicity over ceremony.

## Xcode Project File (project.pbxproj)

Projects are created and maintained by writing `project.pbxproj` directly, not via the Xcode GUI. When adding new Swift files to a target that doesn't use file system sync, register in four places:

1. **PBXBuildFile section** — build file entry
2. **PBXFileReference section** — file reference entry
3. **PBXGroup** — add to the appropriate group's `children` list
4. **PBXSourcesBuildPhase** — add build file to the target's Sources phase

ID patterns vary per project but follow a consistent incrementing convention within each project. Test targets may use `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), meaning test files are auto-discovered.

## Build Verification

Always verify the build after any code change:

```bash
xcodebuild -project ProjectName.xcodeproj -scheme ProjectName \
  -destination 'generic/platform=iOS' build \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

A clean result ends with `** BUILD SUCCEEDED **`. Fix any errors before considering a task complete.

## Testing

```bash
xcodebuild -project ProjectName.xcodeproj -scheme ProjectName \
  -destination 'platform=iOS Simulator,name=iPhone 16' test \
  CODE_SIGNING_ALLOWED=NO
```

- Use **in-memory containers** for SwiftData tests (fast, isolated)
- Use the **Swift Testing framework** (`import Testing`, `@Test`, `#expect()`) for newer projects
- **Extract pure decision logic as `internal static` methods** with explicit parameters so tests can inject values directly — avoid testing through singletons, UserDefaults, or system frameworks
- Test files that use Foundation types must `import Foundation` alongside `import Testing`

## Key Patterns

### Persistence

- **SwiftData** for structured app data (e.g. PillRecord)
- **UserDefaults / @AppStorage** for preferences, settings, and cache
- **iOS Keychain** for API credentials and secrets (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- **JSON encoding** in UserDefaults for lightweight structured data (e.g. portfolio, saved places)

### Networking

- **Graceful degradation:** The app should work with reduced functionality when API calls fail. Isolate independent API calls in separate `do/catch` blocks so one failure doesn't take down the others
- **Task cancellation:** Cancel in-flight tasks before starting new ones. Check `Task.isCancelled` before publishing results
- **Debouncing:** Use 0.8-second debounce for rapid user interactions (e.g. map panning) to prevent API spam
- **Caching:** Cache API responses with TTLs in UserDefaults (e.g. 5-min for quotes, 30-min for historical data)

### Concurrency

- **Actor-based services** for thread-safe API clients
- **`async let` for parallel fetching** of independent data
- Wrap work in an unstructured `Task` inside `.refreshable` to prevent SwiftUI from cancelling structured concurrency children when `@Published` properties trigger re-renders
- **`Task.detached(.utility)`** for background work like photo library scanning
- **Swift 6 concurrency:** Use `guard let self else { return }` in detached task closures; copy mutable `var` to `let` before `await MainActor.run`

### Timers

- Prefer **one-shot `DispatchWorkItem`** over polling `Timer.publish`
- Avoid always-running timers — schedule on demand, cancel on completion

### SwiftUI

- **`.id()` modifier** on views for animated identity changes (e.g. month transitions)
- **GeometryReader** for proportional layouts
- **Asymmetric slide transitions** with tracked direction state
- **NavigationStack** with `.toolbar` and `.sheet` for settings
- **`.refreshable`** for pull-to-refresh
- **Segmented pickers** for mode selection (chart periods, map styles, etc.)
- **@AppStorage** for persisting UI preferences across launches
- **`.contentShape(Rectangle())`** for full-row tap targets

## App Icons

Generated programmatically using **Python/Pillow** — not designed in a graphics tool. Three variants at 1024x1024:

- **Standard** (light mode)
- **Dark** (dark mode)
- **Tinted** (greyscale for tinted mode)

Referenced in `Contents.json` with `luminosity` appearance variants. Use `Image.new("RGB", ...)` not `"RGBA"` — iOS strips alpha for app icons, causing compositing artefacts with semi-transparent overlays.

## Documentation

Each project includes four living documents that must be kept up to date as the project evolves:

### CLAUDE.md (developer reference)

The comprehensive knowledge base for Claude Code sessions. Must be updated whenever:
- A new file, model, view, or service is added or removed
- An architectural decision is made or changed
- A new API is integrated or an existing one changes
- A non-obvious bug is fixed or a gotcha is discovered
- Build configuration, test coverage, or project structure changes

This is the single source of truth for project context. A future session should be able to read CLAUDE.md and understand the entire project without exploring the codebase.

### README.md (user-facing)

The public-facing project overview. Must be updated whenever:
- Features are added, changed, or removed
- Setup instructions change (new dependencies, API keys, permissions)
- The project structure changes significantly
- Screenshots become outdated (note when a new screenshot is needed)

Keep it concise and practical — someone should be able to clone the repo and get running by following the README.

### architecture.html (architecture diagrams)

Interactive Mermaid.js diagrams rendered in a standalone HTML file. Must be updated whenever:
- The view hierarchy changes (new views, removed views, restructured navigation)
- Data flow changes (new services, new API integrations, changed data pipelines)
- New major subsystems are added (e.g. a notification system, a caching layer, a P&L calculator)

Use `graph TD` (top-down) for readability on narrow screens. Load Mermaid.js from CDN. Apply the shared dark theme with CSS custom properties and project-appropriate accent colours.

### tutorial.html (build narrative)

A step-by-step record of how the app was built through Claude Code conversation. Must be updated whenever:
- A significant new feature is added via a notable prompt interaction
- A major refactor or architectural change is made
- An interesting problem is solved through iterative prompting

Capture the essence of the prompt, the approach taken, and the outcome. This documents the collaborative development process and serves as a guide for building similar features in future projects.

**Prompt tone:** Prompts recorded in the tutorial should sound collaborative, not demanding. Use phrases like "Could we try...", "How about...", "Would you mind...", "Would it be worth...", "I'd love it if..." rather than "Make...", "Add...", "I want...", "I need...". When describing problems, use "I'm seeing..." or "I'm noticing..." rather than assertive declarations. The tone should reflect a partnership — two people working together on something, not instructions being issued.

### Formatting conventions

- Use plain Markdown in `.md` files (no inline HTML except README badges). Images must use `![alt](src)` syntax, not `<img>` tags
- HTML docs use a shared dark theme with CSS custom properties and Mermaid.js loaded from CDN
- HTML docs include a hero screenshot in a phone-frame wrapper (black background, rounded corners, drop shadow) below the title/badges

## Common Gotchas

- **Keychain: always delete before add** to avoid `errSecDuplicateItem`
- **SwiftUI `.refreshable` cancels structured concurrency** — wrap network calls in an unstructured `Task`
- **Wikimedia geosearch caps at 10,000m radius** — clamp before sending
- **Wikipedia disambiguation pages** — filter out articles where extract contains "may refer to"

---

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
