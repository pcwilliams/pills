
# iOS Development Conventions

Native iOS apps built with Swift and SwiftUI. No storyboards, no external dependencies.

## Tech Stack

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
├── CLAUDE.md                    # Developer reference
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

Smaller projects (e.g. Where) may flatten this into fewer files — simplicity over ceremony.

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

### Simulator Testing with Launch Arguments

For apps with multiple modes or views, add **launch argument parsing** so visual testing can be fully automated from the command line — never try to tap simulator UI with AppleScript (it's unreliable). Parse `ProcessInfo.processInfo.arguments` in the root view to accept flags like `-mode <value>`.

**Launch arguments must override persisted settings.** When an app uses `@AppStorage` or `UserDefaults`, launch arguments must be applied *after* persistence loads (e.g. in `onAppear`) so they take priority. Return optionals from launch-arg parsers (nil = no override).

```swift
// In ContentView or root view
private static func initialMode() -> Mode {
    let args = ProcessInfo.processInfo.arguments
    if let idx = args.firstIndex(of: "-mode"), idx + 1 < args.count {
        return Mode(rawValue: args[idx + 1]) ?? .default
    }
    return .default
}
```

Then test each mode from the command line:

```bash
xcrun simctl install booted path/to/App.app
xcrun simctl privacy booted grant microphone com.bundle.id  # if needed
xcrun simctl terminate booted com.bundle.id
xcrun simctl launch booted com.bundle.id -- -mode someMode
sleep 2
xcrun simctl io booted screenshot /tmp/screenshot.png
```

This pattern was established in ShiftingSands and adopted in Spectrum. Every new project with multiple visual states should support this from the start.

### Bundled Test Files for Hardware-Dependent Features

When a feature depends on hardware input (microphone, GPS, camera), create **bundled test files** that exercise the same code path in the simulator:

- **Audio**: Generate WAV files with Python — pure tones (440Hz sine), multi-tone sequences, periodic beats. Bundle and play via `-testfile <name>` launch argument.
- **Location**: Bundle JSON files with known GPS coordinates for map-based testing.
- **Images**: Bundle sample photos with known EXIF data for photo-processing features.

The DSP/processing pipeline shouldn't know or care whether input comes from hardware or a test file.

```python
import wave, struct, math
sample_rate = 44100
samples = []
for freq, duration in [(261.63, 1.5), (329.63, 1.5), (440.0, 1.5), (0, 1.0)]:
    for i in range(int(sample_rate * duration)):
        t = i / sample_rate
        value = 0.7 * math.sin(2 * math.pi * freq * t) if freq > 0 else 0
        samples.append(int(value * 32767))
with wave.open('test.wav', 'w') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(sample_rate)
    f.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
```

### Diagnostic Logging for Algorithm Debugging

For complex algorithms (DSP, ML, signal processing), add **structured diagnostic logging** gated behind a launch argument:

```swift
// In the engine/service
static var verboseLogging = false

// In the algorithm
if Self.verboseLogging {
    alog("PITCH DBG: acPeak=\(peak) lag=\(lag) freq=\(freq)Hz")
}

// In ContentView onAppear
if args.contains("-pitchlog") { AudioEngine.verboseLogging = true }
```

**What to log:** algorithm confidence metrics, which branch/threshold was taken, input characteristics, state changes.

**What NOT to log every frame:** raw sample values, full array contents, unchanged state.

Use change-only logging for display state and periodic logging for diagnostics (every Nth frame).

### Reading Logs from Simulator and Device

```bash
# Simulator: read the app's Documents directory
CONTAINER=$(xcrun simctl get_app_container booted com.bundle.id data)
cat "$CONTAINER/Documents/app.log"

# Clear log before a test run
> "$CONTAINER/Documents/app.log"

# Device: stream logs via:
xcrun devicectl device syslog --device <udid>
```

### Performance Testing in the DSP/Rendering Pipeline

For real-time processing, measure execution time against the time budget:

```swift
let start = CACurrentMediaTime()
// ... processing ...
let elapsed = CACurrentMediaTime() - start
dspTimingSum += elapsed
dspTimingCount += 1
if elapsed > dspTimingMax { dspTimingMax = elapsed }
if dspTimingCount % 100 == 0 {
    let avgMs = (dspTimingSum / Double(dspTimingCount)) * 1000
    let maxMs = dspTimingMax * 1000
    let budgetMs = Double(bufferSize) / Double(sampleRate) * 1000
    alog("DSP PERF: avg=\(avgMs)ms, max=\(maxMs)ms, budget=\(budgetMs)ms")
}
```

Budget = time between callbacks (e.g. 2048 samples at 44.1kHz = 46.4ms). If average exceeds ~50% of budget, optimise before adding features.

### Simulator vs Device Differences

The simulator does NOT replicate everything. Always test on device for:

- **Microphone input** (simulator has no mic hardware)
- **GPS / CoreLocation** (simulator uses simulated locations)
- **Audio session behaviour** (`.playAndRecord` fails on simulator — use `.playback` with `#if targetEnvironment(simulator)`)
- **Sample rates** (simulator often uses 44.1kHz, device may use 48kHz — parameterise, don't hardcode)
- **Real-world signal characteristics** (voice has harmonics, vibrato, breath noise that pure test tones lack)
- **Hardware format edge cases** (0 Hz sample rate, 0 input channels — detect and alert the user)

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

### GPU rendering — 3D surfaces, terrain, waterfalls, landscapes

For any feature that renders a 2D value field as a lit, animated 3D surface (frequency × time, day × hour, X × Y × any-Z, ridgelines, terrain), use the **`3dsurface`** skill. It captures the canonical Metal pipeline, mesh, camera math, lighting, smoothing, and animation patterns extracted from HeartMap and Spectrum — including the non-obvious decisions (fixed colour scales, smoothing-decoupled-from-colour, face normals, locked camera) that make a surface read as *stunning* rather than just correct.

### Apple Health / HealthKit

For any feature that reads heart rate, steps, workouts, sleep, or other Apple Health data, use the **`healthkit`** skill. It captures the actor-based service shape, authorization (single combined prompt; read perms aren't queryable), the optimized fetch patterns (per-month queries, server-side bucketing via `HKStatisticsCollectionQuery + .cumulativeSum`, parallel `async let`), the three-phase load (disk-cache seed → current-month refresh → background stream), the empty-result fallback to demo data, infinity-safe JSON disk caching, workout activity type → label/symbol mapping, and entitlements/provisioning gotchas (wildcard profiles can't carry HealthKit).

For *clinical interpretation* of that data — fitness scores, resting heart rate calculations, AHA active-minute zones, age-adjusted scoring, evidence-based step thresholds — use the **`health`** skill. It's platform-agnostic (useful in web dashboards too) and always carries an explicit "not medical advice" disclaimer.

## App Icons

Generated programmatically using **Python/Pillow** — not designed in a graphics tool. Three variants at 1024x1024:

- **Standard** (light mode)
- **Dark** (dark mode)
- **Tinted** (greyscale for tinted mode)

Referenced in `Contents.json` with `luminosity` appearance variants. Use `Image.new("RGB", ...)` not `"RGBA"` — iOS strips alpha for app icons, causing compositing artefacts with semi-transparent overlays.

## Documentation

Each project includes four living documents that must be kept up to date:

### CLAUDE.md (developer reference)

Must be updated whenever: a file, model, view, or service is added/removed; an architectural decision is made; a new API is integrated; a non-obvious bug is fixed; build configuration or project structure changes.

This is the single source of truth for project context. A future session should be able to read CLAUDE.md and understand the entire project without exploring the codebase.

### README.md (user-facing)

Must be updated whenever: features are added/changed/removed; setup instructions change; project structure changes significantly; screenshots become outdated.

### architecture.html (architecture diagrams)

Interactive Mermaid.js diagrams. Must be updated whenever: view hierarchy changes; data flow changes; new major subsystems are added.

Use `graph TD` for readability. Load Mermaid.js from CDN. Apply the shared dark theme with CSS custom properties and project-appropriate accent colours.

### tutorial.html (build narrative)

A step-by-step record of how the app was built. Must be updated whenever: a significant new feature is added; a major refactor is made; an interesting problem is solved through iterative prompting.

**Prompt tone:** Use collaborative language — "Could we try...", "How about...", "I'd love it if..." rather than imperatives. Use "I'm seeing..." for problems rather than assertive declarations.

### Formatting conventions

- Plain Markdown in `.md` files (no inline HTML except README badges). Images use `![alt](src)` syntax, not `<img>` tags
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

Shared iOS conventions (Swift 5 / SwiftUI / MVVM, SwiftData persistence, Xcode pbxproj editing, build verification, simulator launch-arg testing, app icon generation) live in the `ios` skill referenced above.

## Tech Stack
- **Persistence:** SwiftData with explicit `ModelContainer` in `PillsApp.init()` so it can be shared with `NotificationManager` for background queries
- **Minimum Target:** iOS 17.0
- **Device:** iPhone only, portrait-only

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

For day-to-day device rebuilds, use the bundled `run_phone.sh` — it
builds (signed, via `id=$IPHONE_BUILD_ID -allowProvisioningUpdates
DEVELOPMENT_TEAM=$APPLE_TEAM_ID`), installs via `devicectl`, and
launches in one step:

```bash
./run_phone.sh                              # plain launch
```

`run_phone.sh` reads `APPLE_TEAM_ID` / `IPHONE_UDID` / `IPHONE_BUILD_ID`
from `~/appledev/setupenv.sh`. The bare
`-destination "platform=iOS,name=…"` form silently produces an unsigned
`.app` that fails to install with `No code signature found` — the script
side-steps that.

```bash
# Build (skipping code signing for CI)
xcodebuild -project Pills.xcodeproj -scheme Pills -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO

# Run unit tests (requires simulator)
xcodebuild -project Pills.xcodeproj -scheme Pills -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO
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
- Development Team: (your Apple Developer Team ID)
- **Testability:** Extract pure decision logic as `internal static` methods with explicit parameters so tests can inject values directly, avoiding singletons, UserDefaults, and system frameworks
- **Timers:** Prefer one-shot `DispatchWorkItem` over polling `Timer.publish`. Avoid always-running timers — schedule on demand, cancel on completion
- **Documentation:** Use plain Markdown syntax in `.md` files (no inline HTML). `tutorial.html` and `architecture.html` use a shared dark theme with CSS custom properties and Mermaid.js diagrams
