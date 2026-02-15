import SwiftUI

struct StreakView: View {
    let records: [PillRecord]

    private var streak: Int {
        Self.calculateStreak(from: records)
    }

    static func calculateStreak(from records: [PillRecord]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var count = 0

        // Check if today is fully complete
        let todayRecord = records.first { calendar.isDate($0.date, inSameDayAs: today) }
        var currentDate: Date

        if let todayRecord, todayRecord.morningTaken && todayRecord.eveningTaken {
            count = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: today)!
        } else {
            currentDate = calendar.date(byAdding: .day, value: -1, to: today)!
        }

        // Count consecutive complete days going backwards
        while true {
            let record = records.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
            if let record, record.morningTaken && record.eveningTaken {
                count += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }

        return count
    }

    var body: some View {
        if streak > 0 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(streak) day streak")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )
        }
    }
}
