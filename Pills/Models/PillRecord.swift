import Foundation
import SwiftData

@Model
final class PillRecord {
    var date: Date
    var morningTaken: Bool
    var eveningTaken: Bool

    init(date: Date, morningTaken: Bool = false, eveningTaken: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.morningTaken = morningTaken
        self.eveningTaken = eveningTaken
    }

    /// The calendar day this record belongs to, independent of the phone's current time zone.
    var day: DayKey { DayKey(recordDate: date) }

    /// Toggle a period on the day containing `date`, creating the record if needed.
    /// Shared by ContentView and the tests. Doesn't save — the caller does.
    @discardableResult
    static func toggle(
        _ period: PillPeriod,
        on date: Date,
        in records: [PillRecord],
        context: ModelContext,
        calendar: Calendar = .current
    ) -> PillRecord {
        if let record = records.record(on: date, calendar: calendar) {
            switch period {
            case .morning: record.morningTaken.toggle()
            case .evening: record.eveningTaken.toggle()
            }
            return record
        }
        let record = PillRecord(
            date: calendar.startOfDay(for: date),
            morningTaken: period == .morning,
            eveningTaken: period == .evening
        )
        context.insert(record)
        return record
    }
}

/// A calendar day (year, month, day) used to match records to calendar cells.
///
/// Records store local midnight of the time zone the phone was in when they were created
/// (e.g. 23:00 UTC for a UK summer day, 04:00 UTC for a US East Coast day). Comparing that
/// instant in whatever zone the phone is in *now* shifts records a day after travelling, so
/// instead a record's day is the UTC date of `date + 12h`: local midnight anywhere from
/// UTC-12 to UTC+12 lands on the intended day. No stored data changes.
struct DayKey: Hashable {
    let year: Int
    let month: Int
    let day: Int

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// The day a stored record represents.
    init(recordDate: Date) {
        let c = Self.utc.dateComponents([.year, .month, .day], from: recordDate.addingTimeInterval(12 * 3600))
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// The day a local date falls on (calendar cells, "today") in the given calendar's time zone.
    init(localDate: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: localDate)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

extension Array where Element == PillRecord {
    /// The record for the calendar day containing `date` (local to `calendar`), if any.
    func record(on date: Date, calendar: Calendar = .current) -> PillRecord? {
        let key = DayKey(localDate: date, calendar: calendar)
        return first { $0.day == key }
    }
}
