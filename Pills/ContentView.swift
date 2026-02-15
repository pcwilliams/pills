import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [PillRecord]

    @State private var displayedMonth: Date = Date()
    @State private var slideDirection: Edge = .leading
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    // History lock
    @AppStorage("historyLocked") private var historyLocked = true
    @AppStorage("unlockTimestamp") private var unlockTimestamp: Double = 0
    @State private var showUnlockAlert = false
    @State private var pendingToggle: (date: Date, isMorning: Bool)?
    @State private var relockTask: DispatchWorkItem?

    private let calendar = Calendar.current

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Month navigation header
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .opacity(isCurrentMonth ? 0.3 : 1.0)
                .disabled(isCurrentMonth)

                Button(action: {
                    if historyLocked {
                        unlock()
                    } else {
                        relock()
                    }
                }) {
                    Image(systemName: historyLocked ? "lock.fill" : "lock.open.fill")
                        .font(.title3)
                        .foregroundColor(historyLocked ? .secondary : .accentColor)
                }
                .padding(.leading, 8)

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal)

            // Streak
            StreakView(records: allRecords)

            // Calendar fills remaining space
            CalendarView(
                displayedMonth: displayedMonth,
                records: allRecords,
                onToggleMorning: { date in toggleMorning(for: date) },
                onToggleEvening: { date in toggleEvening(for: date) }
            )
            .id(displayedMonth)
            .transition(.asymmetric(
                insertion: .move(edge: slideDirection),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
            ))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width > 50 {
                            changeMonth(by: -1)
                        } else if value.translation.width < -50 && !isCurrentMonth {
                            changeMonth(by: 1)
                        }
                    }
            )
            .clipped()

            // Legend
            legendView
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .onAppear { scheduleRelockIfNeeded() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationManager.shared.rescheduleAll()
                scheduleRelockIfNeeded()
            }
        }
        .alert("History is Locked", isPresented: $showUnlockAlert) {
            Button("Unlock") {
                unlock()
                if let toggle = pendingToggle {
                    if toggle.isMorning {
                        performToggleMorning(for: toggle.date)
                    } else {
                        performToggleEvening(for: toggle.date)
                    }
                }
                pendingToggle = nil
            }
            Button("Cancel", role: .cancel) {
                pendingToggle = nil
            }
        } message: {
            Text("Unlock editing for past days? It will relock after 10 minutes.")
        }
    }

    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: .cyan, label: "Morning")
            legendItem(color: .orange, label: "Evening")
            legendItem(color: .gray, label: "Taken")
        }
        .font(.caption)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    private func changeMonth(by value: Int) {
        slideDirection = value > 0 ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }

    private func toggleMorning(for date: Date) {
        let isToday = calendar.isDateInToday(date)
        if !isToday && historyLocked {
            pendingToggle = (date: date, isMorning: true)
            showUnlockAlert = true
            return
        }
        performToggleMorning(for: date)
    }

    private func toggleEvening(for date: Date) {
        let isToday = calendar.isDateInToday(date)
        if !isToday && historyLocked {
            pendingToggle = (date: date, isMorning: false)
            showUnlockAlert = true
            return
        }
        performToggleEvening(for: date)
    }

    private func performToggleMorning(for date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        if let record = allRecords.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            record.morningTaken.toggle()
            if record.morningTaken && calendar.isDateInToday(date) {
                NotificationManager.shared.cancelTodayMorning()
            }
        } else {
            let newRecord = PillRecord(date: startOfDay, morningTaken: true)
            modelContext.insert(newRecord)
            if calendar.isDateInToday(date) {
                NotificationManager.shared.cancelTodayMorning()
            }
        }
    }

    private func performToggleEvening(for date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        if let record = allRecords.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            record.eveningTaken.toggle()
            if record.eveningTaken && calendar.isDateInToday(date) {
                NotificationManager.shared.cancelTodayEvening()
            }
        } else {
            let newRecord = PillRecord(date: startOfDay, eveningTaken: true)
            modelContext.insert(newRecord)
            if calendar.isDateInToday(date) {
                NotificationManager.shared.cancelTodayEvening()
            }
        }
    }

    private func unlock() {
        historyLocked = false
        unlockTimestamp = Date().timeIntervalSince1970
        scheduleRelock(after: 600)
    }

    private func relock() {
        relockTask?.cancel()
        relockTask = nil
        historyLocked = true
        unlockTimestamp = 0
    }

    private func scheduleRelock(after seconds: Double) {
        relockTask?.cancel()
        let task = DispatchWorkItem { [self] in relock() }
        relockTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    private func scheduleRelockIfNeeded() {
        guard !historyLocked, unlockTimestamp > 0 else { return }
        let elapsed = Date().timeIntervalSince1970 - unlockTimestamp
        if elapsed >= 600 {
            relock()
        } else {
            scheduleRelock(after: 600 - elapsed)
        }
    }
}
