import XCTest
import SwiftData
@testable import Pills

final class PillsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    private let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: PillRecord.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(daysFromToday offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    private func fetchRecords() throws -> [PillRecord] {
        try context.fetch(FetchDescriptor<PillRecord>())
    }

    /// Same path as ContentView.performToggleMorning: shared PillRecord.toggle, then save
    private func performToggleMorning(for date: Date, calendar: Calendar? = nil) throws {
        PillRecord.toggle(.morning, on: date, in: try fetchRecords(), context: context, calendar: calendar ?? self.calendar)
        try context.save()
    }

    /// Same path as ContentView.performToggleEvening: shared PillRecord.toggle, then save
    private func performToggleEvening(for date: Date, calendar: Calendar? = nil) throws {
        PillRecord.toggle(.evening, on: date, in: try fetchRecords(), context: context, calendar: calendar ?? self.calendar)
        try context.save()
    }

    // MARK: - PillRecord Model

    func testPillRecordDateNormalizesToStartOfDay() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 30
        let dateWithTime = calendar.date(from: components)!

        let record = PillRecord(date: dateWithTime)

        let expectedStart = calendar.startOfDay(for: dateWithTime)
        XCTAssertEqual(record.date, expectedStart)
    }

    func testPillRecordDefaultsToNotTaken() {
        let record = PillRecord(date: Date())

        XCTAssertFalse(record.morningTaken)
        XCTAssertFalse(record.eveningTaken)
    }

    // MARK: - Toggle Morning (user taps morning bar)

    func testToggleMorningCreatesRecordWhenNoneExists() throws {
        let today = makeDate(daysFromToday: 0)

        try performToggleMorning(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].morningTaken)
        XCTAssertFalse(records[0].eveningTaken)
    }

    func testToggleMorningTogglesExistingRecord() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false)
        context.insert(record)
        try context.save()

        try performToggleMorning(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].morningTaken)
    }

    func testToggleMorningOffWhenAlreadyTaken() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true)
        context.insert(record)
        try context.save()

        try performToggleMorning(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].morningTaken)
    }

    // MARK: - Toggle Evening (user taps evening bar)

    func testToggleEveningCreatesRecordWhenNoneExists() throws {
        let today = makeDate(daysFromToday: 0)

        try performToggleEvening(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].morningTaken)
        XCTAssertTrue(records[0].eveningTaken)
    }

    func testToggleEveningTogglesExistingRecord() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, eveningTaken: false)
        context.insert(record)
        try context.save()

        try performToggleEvening(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].eveningTaken)
    }

    func testToggleEveningOffWhenAlreadyTaken() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, eveningTaken: true)
        context.insert(record)
        try context.save()

        try performToggleEvening(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].eveningTaken)
    }

    // MARK: - Independent Toggle Behavior

    func testToggleMorningDoesNotAffectEvening() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false, eveningTaken: true)
        context.insert(record)
        try context.save()

        try performToggleMorning(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].morningTaken)
        XCTAssertTrue(records[0].eveningTaken, "Evening should remain unchanged")
    }

    func testToggleEveningDoesNotAffectMorning() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: false)
        context.insert(record)
        try context.save()

        try performToggleEvening(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].morningTaken, "Morning should remain unchanged")
        XCTAssertTrue(records[0].eveningTaken)
    }

    func testToggleBothPillsOnSameDay() throws {
        let today = makeDate(daysFromToday: 0)

        try performToggleMorning(for: today)
        try performToggleEvening(for: today)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1, "Should reuse same record, not create two")
        XCTAssertTrue(records[0].morningTaken)
        XCTAssertTrue(records[0].eveningTaken)
    }

    func testToggleDifferentDaysCreatesSeparateRecords() throws {
        let today = makeDate(daysFromToday: 0)
        let yesterday = makeDate(daysFromToday: -1)

        try performToggleMorning(for: today)
        try performToggleMorning(for: yesterday)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 2)
    }

    // MARK: - Streak Calculation

    func testStreakWithNoRecords() {
        let streak = StreakView.calculateStreak(from: [])
        XCTAssertEqual(streak, 0)
    }

    func testStreakWithTodayComplete() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: true)

        let streak = StreakView.calculateStreak(from: [record])
        XCTAssertEqual(streak, 1)
    }

    func testStreakWithTodayIncomplete() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: false)

        let streak = StreakView.calculateStreak(from: [record])
        XCTAssertEqual(streak, 0)
    }

    func testStreakConsecutiveDays() {
        let records = (-2...0).map { offset in
            PillRecord(date: makeDate(daysFromToday: offset), morningTaken: true, eveningTaken: true)
        }

        let streak = StreakView.calculateStreak(from: records)
        XCTAssertEqual(streak, 3)
    }

    func testStreakBreaksOnMissedDay() {
        let records = [
            PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: true),
            // day -1 missing
            PillRecord(date: makeDate(daysFromToday: -2), morningTaken: true, eveningTaken: true),
        ]

        let streak = StreakView.calculateStreak(from: records)
        XCTAssertEqual(streak, 1)
    }

    func testStreakBreaksOnPartialDay() {
        let records = [
            PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: true),
            PillRecord(date: makeDate(daysFromToday: -1), morningTaken: true, eveningTaken: false),
            PillRecord(date: makeDate(daysFromToday: -2), morningTaken: true, eveningTaken: true),
        ]

        let streak = StreakView.calculateStreak(from: records)
        XCTAssertEqual(streak, 1)
    }

    func testStreakStartsFromYesterdayWhenTodayIncomplete() {
        let records = [
            PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: false),
            PillRecord(date: makeDate(daysFromToday: -1), morningTaken: true, eveningTaken: true),
            PillRecord(date: makeDate(daysFromToday: -2), morningTaken: true, eveningTaken: true),
        ]

        let streak = StreakView.calculateStreak(from: records)
        XCTAssertEqual(streak, 2)
    }

    // MARK: - Double-Toggle Round-Trip

    func testDoubleTapMorningReturnsToOriginalState() throws {
        let today = makeDate(daysFromToday: 0)

        try performToggleMorning(for: today) // off -> on
        try performToggleMorning(for: today) // on -> off

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].morningTaken, "Double-tap should return to not-taken")
    }

    func testDoubleTapEveningReturnsToOriginalState() throws {
        let today = makeDate(daysFromToday: 0)

        try performToggleEvening(for: today) // off -> on
        try performToggleEvening(for: today) // on -> off

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].eveningTaken, "Double-tap should return to not-taken")
    }

    // MARK: - SwiftData Persistence

    func testRecordsSurviveContextRebuild() throws {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: true)
        context.insert(record)
        try context.save()

        // Create a new context from the same container (simulates app relaunch)
        let newContext = ModelContext(container)
        let fetched = try newContext.fetch(FetchDescriptor<PillRecord>())

        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched[0].morningTaken)
        XCTAssertTrue(fetched[0].eveningTaken)
        XCTAssertEqual(fetched[0].day, DayKey(localDate: today, calendar: calendar))
    }

    // MARK: - Record Lookup by Date

    func testToggleMatchesRecordRegardlessOfTimeComponent() throws {
        let today = makeDate(daysFromToday: 0)

        // Insert a record at start of day
        let record = PillRecord(date: today, morningTaken: false)
        context.insert(record)
        try context.save()

        // Toggle using a date with a time component (e.g. user taps at 2:30 PM)
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = 14
        components.minute = 30
        let afternoonDate = calendar.date(from: components)!

        try performToggleMorning(for: afternoonDate)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1, "Should match existing record, not create a second")
        XCTAssertTrue(records[0].morningTaken)
    }

    // MARK: - Time Zones (DayKey)

    private func zone(_ id: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: id)!
        return cal
    }

    private func utcInstant(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A record as it would be stored by a phone in `zone`: local midnight of that day.
    private func storedRecord(year: Int, month: Int, day: Int, in zoneId: String,
                              morning: Bool = true, evening: Bool = true) -> PillRecord {
        let cal = zone(zoneId)
        let midnight = cal.date(from: DateComponents(year: year, month: month, day: day))!
        let record = PillRecord(date: midnight, morningTaken: morning, eveningTaken: evening)
        record.date = midnight  // init normalises with Calendar.current; keep the other zone's midnight
        return record
    }

    func testDayKeyForStoredMidnightsSeenOnDevice() {
        // The four forms found in the real store (Sep 2026 audit)
        XCTAssertEqual(DayKey(recordDate: utcInstant("2026-03-01T00:00:00Z")), DayKey(year: 2026, month: 3, day: 1))   // UK winter
        XCTAssertEqual(DayKey(recordDate: utcInstant("2026-07-09T23:00:00Z")), DayKey(year: 2026, month: 7, day: 10))  // UK summer
        XCTAssertEqual(DayKey(recordDate: utcInstant("2026-09-22T22:00:00Z")), DayKey(year: 2026, month: 9, day: 23))  // Central Europe summer
        XCTAssertEqual(DayKey(recordDate: utcInstant("2026-07-09T04:00:00Z")), DayKey(year: 2026, month: 7, day: 9))   // US East summer
    }

    func testDayKeyCoversZonesFromUTCMinus11ToPlus12() {
        for zoneId in ["Pacific/Pago_Pago", "America/Los_Angeles", "America/New_York", "Europe/London",
                       "Europe/Paris", "Asia/Dubai", "Asia/Kolkata", "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland"] {
            let record = storedRecord(year: 2026, month: 7, day: 15, in: zoneId)
            XCTAssertEqual(record.day, DayKey(year: 2026, month: 7, day: 15), zoneId)
        }
    }

    func testUKRecordFoundOnSameDayWhenPhoneIsInNewYork() {
        // Taken in London on 10 July, then viewed in New York the same day
        let records = [storedRecord(year: 2026, month: 7, day: 10, in: "Europe/London", evening: false)]
        let ny = zone("America/New_York")
        let nyMorning = ny.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 9))!
        let found = records.record(on: nyMorning, calendar: ny)
        XCTAssertNotNil(found, "Today's UK record must still show as today in New York")
        XCTAssertTrue(found?.morningTaken ?? false)
        // …and not on the previous New York day
        let nyYesterday = ny.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 21))!
        XCTAssertNil(records.record(on: nyYesterday, calendar: ny))
    }

    func testEuropeRecordFoundOnSameDayBackInUK() {
        let records = [storedRecord(year: 2026, month: 9, day: 23, in: "Europe/Athens")]
        let london = zone("Europe/London")
        XCTAssertNotNil(records.record(on: london.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!, calendar: london))
        XCTAssertNil(records.record(on: london.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 12))!, calendar: london))
    }

    func testToggleAfterTravelUpdatesExistingRecordInsteadOfDuplicating() throws {
        let record = storedRecord(year: 2026, month: 7, day: 10, in: "Europe/London", evening: false)
        context.insert(record)
        try context.save()

        let ny = zone("America/New_York")
        let nyEvening = ny.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 20))!
        try performToggleEvening(for: nyEvening, calendar: ny)

        let records = try fetchRecords()
        XCTAssertEqual(records.count, 1, "Should toggle the UK record, not create a New York duplicate")
        XCTAssertTrue(records[0].morningTaken)
        XCTAssertTrue(records[0].eveningTaken)
    }

    func testScheduleSuppressesTodayAfterTravel() {
        // Morning taken in London; the evening reminder in New York must not re-add the morning
        let records = [storedRecord(year: 2026, month: 7, day: 10, in: "Europe/London", evening: false)]
        let ny = zone("America/New_York")
        let ref = ny.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 6))!
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: records, referenceDate: ref, calendar: ny
        )
        let today = result.filter { $0.dateString == "2026-07-10" }
        XCTAssertEqual(today.map(\.period), [.evening])
    }

    func testScheduleFitsIOSPendingNotificationLimit() {
        XCTAssertLessThanOrEqual(2 * NotificationManager.scheduleDays, 64)
    }

    // MARK: - Notification Helpers

    /// Creates a Date at the given hour:minute on today's date
    private func makeTodayAt(hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    /// Creates a Date at the given hour:minute on a specific day offset from today
    private func makeDateAt(daysFromToday offset: Int, hour: Int, minute: Int) -> Date {
        let day = makeDate(daysFromToday: offset)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    // MARK: - Scheduling Decisions (buildSchedule)

    func testBuildScheduleReturnsEmptyWhenDisabled() {
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: false,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: makeTodayAt(hour: 0, minute: 0),
            calendar: calendar
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testBuildScheduleReturnsBothPeriodsForUntakenDay() {
        // Reference at midnight — both morning (7:00) and evening (21:00) are in the future
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        let periods = Set(todayNotifications.map { $0.period })
        XCTAssertTrue(periods.contains(.morning))
        XCTAssertTrue(periods.contains(.evening))
    }

    func testBuildScheduleSkipsMorningWhenTaken() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let record = PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: false)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [record],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertFalse(todayNotifications.contains { $0.period == .morning })
        XCTAssertTrue(todayNotifications.contains { $0.period == .evening })
    }

    func testBuildScheduleSkipsEveningWhenTaken() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let record = PillRecord(date: makeDate(daysFromToday: 0), morningTaken: false, eveningTaken: true)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [record],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertTrue(todayNotifications.contains { $0.period == .morning })
        XCTAssertFalse(todayNotifications.contains { $0.period == .evening })
    }

    func testBuildScheduleSkipsBothWhenBothTaken() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let record = PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: true)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [record],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertTrue(todayNotifications.isEmpty)
    }

    func testBuildScheduleSkipsPastFireTimes() {
        // Reference at 10:00 — morning (7:00) is past, evening (21:00) is future
        let ref = makeTodayAt(hour: 10, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertFalse(todayNotifications.contains { $0.period == .morning })
        XCTAssertTrue(todayNotifications.contains { $0.period == .evening })
    }

    func testBuildScheduleIncludesFutureFireTimesToday() {
        // Reference at 6:00 — morning (7:00) is future
        let ref = makeTodayAt(hour: 6, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertTrue(todayNotifications.contains { $0.period == .morning })
    }

    func testBuildScheduleCoversScheduleDays() {
        // Midnight reference, no records = 2 notifications per day for every scheduled day
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        XCTAssertEqual(result.count, 2 * NotificationManager.scheduleDays)
        let uniqueDates = Set(result.map { $0.dateString })
        XCTAssertEqual(uniqueDates.count, NotificationManager.scheduleDays)
    }

    func testBuildScheduleUsesCorrectHourAndMinute() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 8, morningMinute: 15,
            eveningHour: 20, eveningMinute: 45,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let mornings = result.filter { $0.period == .morning }
        let evenings = result.filter { $0.period == .evening }
        XCTAssertTrue(mornings.allSatisfy { $0.hour == 8 && $0.minute == 15 })
        XCTAssertTrue(evenings.allSatisfy { $0.hour == 20 && $0.minute == 45 })
    }

    func testBuildScheduleUsesCorrectDateStringFormat() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let dateRegex = /^\d{4}-\d{2}-\d{2}$/
        for notification in result {
            XCTAssertNotNil(notification.dateString.wholeMatch(of: dateRegex),
                            "dateString '\(notification.dateString)' should match yyyy-MM-dd format")
        }
    }

    func testBuildScheduleUsesCorrectBodyText() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let mornings = result.filter { $0.period == .morning }
        let evenings = result.filter { $0.period == .evening }
        XCTAssertTrue(mornings.allSatisfy { $0.body == "Remember to take pills this morning" })
        XCTAssertTrue(evenings.allSatisfy { $0.body == "Remember to take pills this evening" })
    }

    func testBuildScheduleMixedRecordsAcrossDays() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let records = [
            PillRecord(date: makeDate(daysFromToday: 0), morningTaken: true, eveningTaken: false),
            PillRecord(date: makeDate(daysFromToday: 1), morningTaken: false, eveningTaken: true),
            PillRecord(date: makeDate(daysFromToday: 2), morningTaken: true, eveningTaken: true),
        ]
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: records,
            referenceDate: ref,
            calendar: calendar
        )
        // Day 0: morning taken -> evening only
        let day0 = result.filter { $0.dateString == dateString(for: makeDate(daysFromToday: 0)) }
        XCTAssertEqual(day0.count, 1)
        XCTAssertEqual(day0.first?.period, .evening)

        // Day 1: evening taken -> morning only
        let day1 = result.filter { $0.dateString == dateString(for: makeDate(daysFromToday: 1)) }
        XCTAssertEqual(day1.count, 1)
        XCTAssertEqual(day1.first?.period, .morning)

        // Day 2: both taken -> none
        let day2 = result.filter { $0.dateString == dateString(for: makeDate(daysFromToday: 2)) }
        XCTAssertTrue(day2.isEmpty)

        // Remaining days: no records -> both
        for offset in 3..<NotificationManager.scheduleDays {
            let dayN = result.filter { $0.dateString == dateString(for: makeDate(daysFromToday: offset)) }
            XCTAssertEqual(dayN.count, 2, "Day +\(offset) should have 2 notifications")
        }
    }

    func testBuildScheduleTodayAllPastFireTimes() {
        // Reference at 23:00 — both morning (7:00) and evening (21:00) are past for today
        let ref = makeTodayAt(hour: 23, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let todayNotifications = result.filter { $0.dateString == dateString(for: Date()) }
        XCTAssertTrue(todayNotifications.isEmpty)
        // But future days should still have notifications
        XCTAssertEqual(result.count, 2 * (NotificationManager.scheduleDays - 1)) // remaining days x 2
    }

    func testBuildScheduleCustomReminderTimes() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let result = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 9, morningMinute: 30,
            eveningHour: 20, eveningMinute: 15,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        XCTAssertEqual(result.count, 2 * NotificationManager.scheduleDays)
        let mornings = result.filter { $0.period == .morning }
        XCTAssertTrue(mornings.allSatisfy { $0.hour == 9 && $0.minute == 30 })
        let evenings = result.filter { $0.period == .evening }
        XCTAssertTrue(evenings.allSatisfy { $0.hour == 20 && $0.minute == 15 })
    }

    // MARK: - Cancellation ID Generation (notificationIdentifier)

    func testNotificationIdentifierMorningFormat() {
        let today = makeDate(daysFromToday: 0)
        let id = NotificationManager.notificationIdentifier(for: .morning, on: today, calendar: calendar)
        XCTAssertTrue(id.hasPrefix("morning-"))
        XCTAssertEqual(id, "morning-\(dateString(for: today))")
    }

    func testNotificationIdentifierEveningFormat() {
        let today = makeDate(daysFromToday: 0)
        let id = NotificationManager.notificationIdentifier(for: .evening, on: today, calendar: calendar)
        XCTAssertTrue(id.hasPrefix("evening-"))
        XCTAssertEqual(id, "evening-\(dateString(for: today))")
    }

    func testNotificationIdentifierDifferentDates() {
        let today = makeDate(daysFromToday: 0)
        let tomorrow = makeDate(daysFromToday: 1)
        let idToday = NotificationManager.notificationIdentifier(for: .morning, on: today, calendar: calendar)
        let idTomorrow = NotificationManager.notificationIdentifier(for: .morning, on: tomorrow, calendar: calendar)
        XCTAssertNotEqual(idToday, idTomorrow)
    }

    func testNotificationIdentifierMatchesBuildSchedule() {
        let ref = makeTodayAt(hour: 0, minute: 0)
        let schedule = NotificationManager.buildSchedule(
            notificationsEnabled: true,
            morningHour: 7, morningMinute: 0,
            eveningHour: 21, eveningMinute: 0,
            records: [],
            referenceDate: ref,
            calendar: calendar
        )
        let today = makeDate(daysFromToday: 0)
        let morningId = NotificationManager.notificationIdentifier(for: .morning, on: today, calendar: calendar)
        let todayMorning = schedule.first { $0.period == .morning && $0.dateString == dateString(for: today) }
        XCTAssertNotNil(todayMorning)
        XCTAssertEqual(todayMorning?.identifier, morningId)
    }

    // MARK: - Foreground Suppression (shouldSuppressForegroundNotification)

    func testSuppressMorningWhenTaken() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: false)
        let id = "morning-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertTrue(suppress)
    }

    func testDoNotSuppressMorningWhenNotTaken() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false, eveningTaken: false)
        let id = "morning-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress)
    }

    func testSuppressEveningWhenTaken() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false, eveningTaken: true)
        let id = "evening-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertTrue(suppress)
    }

    func testDoNotSuppressEveningWhenNotTaken() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false, eveningTaken: false)
        let id = "evening-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress)
    }

    func testDoNotSuppressWhenNoRecord() {
        let today = makeDate(daysFromToday: 0)
        let id = "morning-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress)
    }

    func testSuppressMorningIgnoresEvening() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: false, eveningTaken: true)
        let id = "morning-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress, "Morning suppression should not be affected by evening state")
    }

    func testSuppressEveningIgnoresMorning() {
        let today = makeDate(daysFromToday: 0)
        let record = PillRecord(date: today, morningTaken: true, eveningTaken: false)
        let id = "evening-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress, "Evening suppression should not be affected by morning state")
    }

    func testSuppressUsesReferenceDateNotOtherDays() {
        let today = makeDate(daysFromToday: 0)
        let yesterday = makeDate(daysFromToday: -1)
        // Only yesterday has morning taken — but referenceDate is today
        let record = PillRecord(date: yesterday, morningTaken: true, eveningTaken: true)
        let id = "morning-\(dateString(for: today))"
        let suppress = NotificationManager.shouldSuppressForegroundNotification(
            identifier: id, records: [record], referenceDate: today, calendar: calendar
        )
        XCTAssertFalse(suppress, "Should only check records matching referenceDate")
    }

    // MARK: - Date String Helper

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        return formatter.string(from: date)
    }
}
