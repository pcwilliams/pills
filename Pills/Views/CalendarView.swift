import SwiftUI

struct CalendarView: View {
    let displayedMonth: Date
    let records: [PillRecord]
    let onToggleMorning: (Date) -> Void
    let onToggleEvening: (Date) -> Void

    private let calendar = Calendar.current
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        GeometryReader { geometry in
            let dayHeaderHeight: CGFloat = 20
            let rowSpacing: CGFloat = 4
            let totalRowSpacing = rowSpacing * CGFloat(weeks.count)
            let rowHeight = (geometry.size.height - dayHeaderHeight - totalRowSpacing) / CGFloat(weeks.count)

            VStack(spacing: rowSpacing) {
                // Day-of-week header row
                HStack(spacing: 2) {
                    ForEach(dayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: dayHeaderHeight)

                // Week rows
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            if let day = week[col] {
                                let date = dateFor(day: day)
                                let today = calendar.startOfDay(for: Date())
                                DayCellView(
                                    day: day,
                                    date: date,
                                    record: record(for: date),
                                    isToday: calendar.isDateInToday(date),
                                    isFuture: date > today,
                                    onToggleMorning: { onToggleMorning(date) },
                                    onToggleEvening: { onToggleEvening(date) }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var firstWeekdayOffset: Int {
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = 1
        let firstOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    private var daysInMonth: [Int] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        return Array(range)
    }

    private var weeks: [[Int?]] {
        var result: [[Int?]] = []
        var currentWeek: [Int?] = Array(repeating: nil, count: 7)
        var dayIndex = firstWeekdayOffset

        for day in daysInMonth {
            currentWeek[dayIndex] = day
            dayIndex += 1
            if dayIndex == 7 {
                result.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
                dayIndex = 0
            }
        }

        if dayIndex > 0 {
            result.append(currentWeek)
        }

        // Pad to 6 rows for consistent height across months
        while result.count < 6 {
            result.append(Array(repeating: nil, count: 7))
        }

        return result
    }

    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = day
        return calendar.date(from: components)!
    }

    private func record(for date: Date) -> PillRecord? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
