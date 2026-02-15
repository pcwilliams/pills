import Foundation
import UserNotifications
import SwiftData

enum PillPeriod: String {
    case morning, evening
}

struct PillNotification: Equatable {
    let period: PillPeriod
    let dateString: String   // "yyyy-MM-dd"
    let hour: Int
    let minute: Int
    let body: String
    var identifier: String { "\(period.rawValue)-\(dateString)" }
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var container: ModelContainer?
    private let defaults = UserDefaults.standard

    private override init() {
        super.init()
    }

    func configure(with container: ModelContainer) {
        self.container = container
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Pure Logic (testable)

    static func buildSchedule(
        notificationsEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningHour: Int,
        eveningMinute: Int,
        records: [PillRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> [PillNotification] {
        guard notificationsEnabled else { return [] }

        let today = calendar.startOfDay(for: referenceDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar

        var result: [PillNotification] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dateString = formatter.string(from: date)
            let startOfDay = calendar.startOfDay(for: date)

            let record = records.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }

            // Morning notification
            if !(record?.morningTaken ?? false) {
                var morningComponents = calendar.dateComponents([.year, .month, .day], from: date)
                morningComponents.hour = morningHour
                morningComponents.minute = morningMinute

                if let fireDate = calendar.date(from: morningComponents), fireDate > referenceDate {
                    result.append(PillNotification(
                        period: .morning,
                        dateString: dateString,
                        hour: morningHour,
                        minute: morningMinute,
                        body: "Remember to take pills this morning"
                    ))
                }
            }

            // Evening notification
            if !(record?.eveningTaken ?? false) {
                var eveningComponents = calendar.dateComponents([.year, .month, .day], from: date)
                eveningComponents.hour = eveningHour
                eveningComponents.minute = eveningMinute

                if let fireDate = calendar.date(from: eveningComponents), fireDate > referenceDate {
                    result.append(PillNotification(
                        period: .evening,
                        dateString: dateString,
                        hour: eveningHour,
                        minute: eveningMinute,
                        body: "Remember to take pills this evening"
                    ))
                }
            }
        }

        return result
    }

    static func notificationIdentifier(for period: PillPeriod, on date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        let dateString = formatter.string(from: date)
        return "\(period.rawValue)-\(dateString)"
    }

    static func shouldSuppressForegroundNotification(
        identifier: String,
        records: [PillRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let isMorning = identifier.hasPrefix("morning-")
        let today = calendar.startOfDay(for: referenceDate)

        guard let record = records.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) else {
            return false
        }

        let alreadyTaken = isMorning ? record.morningTaken : record.eveningTaken
        return alreadyTaken
    }

    // MARK: - Scheduling

    func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard defaults.bool(forKey: "notificationsEnabled") else { return }
        guard let container = container else { return }

        let morningHour = defaults.object(forKey: "morningReminderHour") as? Int ?? 7
        let morningMinute = defaults.object(forKey: "morningReminderMinute") as? Int ?? 0
        let eveningHour = defaults.object(forKey: "eveningReminderHour") as? Int ?? 21
        let eveningMinute = defaults.object(forKey: "eveningReminderMinute") as? Int ?? 0

        let calendar = Calendar.current
        let context = ModelContext(container)

        var records: [PillRecord] = []
        do {
            records = try context.fetch(FetchDescriptor<PillRecord>())
        } catch {
            // Continue with empty records — all notifications will be scheduled
        }

        let schedule = Self.buildSchedule(
            notificationsEnabled: true,
            morningHour: morningHour,
            morningMinute: morningMinute,
            eveningHour: eveningHour,
            eveningMinute: eveningMinute,
            records: records,
            referenceDate: Date(),
            calendar: calendar
        )

        for notification in schedule {
            let content = UNMutableNotificationContent()
            content.title = "Pills"
            content.body = notification.body
            content.sound = .default

            // Parse the date string back to build date components
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: notification.dateString) {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = notification.hour
                components.minute = notification.minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: notification.identifier,
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func cancelTodayMorning() {
        let identifier = Self.notificationIdentifier(for: .morning, on: Date())
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelTodayEvening() {
        let identifier = Self.notificationIdentifier(for: .evening, on: Date())
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App is in foreground — check if pill was already taken
        guard let container = container else {
            completionHandler([])
            return
        }

        let identifier = notification.request.identifier
        let calendar = Calendar.current
        let context = ModelContext(container)

        do {
            let records = try context.fetch(FetchDescriptor<PillRecord>())
            if Self.shouldSuppressForegroundNotification(
                identifier: identifier,
                records: records,
                referenceDate: Date(),
                calendar: calendar
            ) {
                completionHandler([])
                return
            }
        } catch {
            // On error, suppress notification to be safe
            completionHandler([])
            return
        }

        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
