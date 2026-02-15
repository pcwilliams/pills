import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("morningReminderHour") private var morningReminderHour = 7
    @AppStorage("morningReminderMinute") private var morningReminderMinute = 0
    @AppStorage("eveningReminderHour") private var eveningReminderHour = 21
    @AppStorage("eveningReminderMinute") private var eveningReminderMinute = 0
    @AppStorage("historyLocked") private var historyLocked = true

    @State private var permissionDenied = false

    private var morningTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = morningReminderHour
                components.minute = morningReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                morningReminderHour = components.hour ?? 7
                morningReminderMinute = components.minute ?? 0
                NotificationManager.shared.rescheduleAll()
            }
        )
    }

    private var eveningTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = eveningReminderHour
                components.minute = eveningReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                eveningReminderHour = components.hour ?? 21
                eveningReminderMinute = components.minute ?? 0
                NotificationManager.shared.rescheduleAll()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                handleEnableNotifications()
                            } else {
                                NotificationManager.shared.rescheduleAll()
                            }
                        }

                    if notificationsEnabled {
                        DatePicker("Morning", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                        DatePicker("Evening", selection: eveningTimeBinding, displayedComponents: .hourAndMinute)
                    }

                    if permissionDenied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section("History") {
                    Toggle("Lock Past Days", isOn: $historyLocked)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func handleEnableNotifications() {
        Task {
            let status = await NotificationManager.shared.checkPermissionStatus()
            switch status {
            case .notDetermined:
                let granted = await NotificationManager.shared.requestPermission()
                await MainActor.run {
                    if granted {
                        NotificationManager.shared.rescheduleAll()
                    } else {
                        notificationsEnabled = false
                        permissionDenied = true
                    }
                }
            case .denied:
                await MainActor.run {
                    notificationsEnabled = false
                    permissionDenied = true
                }
            case .authorized, .provisional, .ephemeral:
                NotificationManager.shared.rescheduleAll()
            @unknown default:
                break
            }
        }
    }
}
