import Foundation
import Testing
@testable import MusicShuffleCore

struct StatsRangeTests {
    // A Wednesday.
    let now = date("2026-11-18T15:30:00Z")

    @Test(arguments: [
        (StatsUnit.day, "2026-11-18T00:00:00Z", "2026-11-19T00:00:00Z"),
        (.week, "2026-11-16T00:00:00Z", "2026-11-23T00:00:00Z"),
        (.month, "2026-11-01T00:00:00Z", "2026-12-01T00:00:00Z"),
        (.year, "2026-01-01T00:00:00Z", "2027-01-01T00:00:00Z"),
        (.custom, "2026-10-20T00:00:00Z", "2026-11-19T00:00:00Z"),
    ])
    func currentRange(unit: StatsUnit, start: String, end: String) {
        let range = StatsRange.current(unit, now: now, calendar: utcCalendar)
        #expect(range.unit == unit)
        #expect(range.interval == DateInterval(start: date(start), end: date(end)))
    }

    @Test func allTimeHasNoInterval() {
        let range = StatsRange.current(.allTime, now: now, calendar: utcCalendar)
        #expect(range.interval == nil)
        #expect(range.contains(.distantPast))
        #expect(!range.canShift)
    }

    @Test func shiftsByWholeUnits() {
        let week = StatsRange.current(.week, now: now, calendar: utcCalendar)
        #expect(week.shifted(by: -1, calendar: utcCalendar).interval?.start == date("2026-11-09T00:00:00Z"))
        #expect(week.shifted(by: 2, calendar: utcCalendar).interval?.start == date("2026-11-30T00:00:00Z"))

        let month = StatsRange.current(.month, now: date("2026-01-31T12:00:00Z"), calendar: utcCalendar)
        #expect(month.shifted(by: 1, calendar: utcCalendar).interval
                == DateInterval(start: date("2026-02-01T00:00:00Z"), end: date("2026-03-01T00:00:00Z")))
    }

    @Test func customRangeIncludesWholeDaysInEitherOrder() {
        let range = StatsRange.custom(from: date("2026-11-05T18:00:00Z"), through: date("2026-11-02T09:00:00Z"),
                                      calendar: utcCalendar)
        #expect(range.interval == DateInterval(start: date("2026-11-02T00:00:00Z"), end: date("2026-11-06T00:00:00Z")))
        #expect(range.contains(date("2026-11-05T23:59:59Z")))
        #expect(!range.contains(date("2026-11-06T00:00:00Z")))
        #expect(!range.canShift)
    }
}
