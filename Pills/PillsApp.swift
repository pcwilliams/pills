import SwiftUI
import SwiftData

@main
struct PillsApp: App {
    let container: ModelContainer

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "morningReminderHour": 7,
            "morningReminderMinute": 0,
            "eveningReminderHour": 21,
            "eveningReminderMinute": 0,
        ])

        do {
            container = try ModelContainer(for: PillRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        NotificationManager.shared.configure(with: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
