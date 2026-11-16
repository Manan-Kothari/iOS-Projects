//
//  StatsRange.swift
//  MusicShuffleCore
//

import Foundation

public enum StatsUnit: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year, allTime, custom

    public var id: Self { self }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .allTime, .custom: nil
        }
    }
}

/// The time range of a statistics view. The interval includes its start and excludes its end.
public struct StatsRange: Hashable, Sendable {
    public let unit: StatsUnit
    /// `nil` for all time.
    public let interval: DateInterval?

    init(unit: StatsUnit, interval: DateInterval?) {
        self.unit = unit
        self.interval = interval
    }

    /// The range of `unit` that contains `now`. For `.custom`, the last 30 days.
    public static func current(_ unit: StatsUnit, now: Date = .now, calendar: Calendar = .current) -> StatsRange {
        if let component = unit.calendarComponent, let interval = calendar.dateInterval(of: component, for: now) {
            return StatsRange(unit: unit, interval: interval)
        }
        if unit == .custom {
            let start = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            return custom(from: start, through: now, calendar: calendar)
        }
        return StatsRange(unit: .allTime, interval: nil)
    }

    /// A range that includes all of the first day through all of the last day.
    public static func custom(from first: Date, through last: Date, calendar: Calendar = .current) -> StatsRange {
        let start = calendar.startOfDay(for: min(first, last))
        let lastDay = calendar.startOfDay(for: max(first, last))
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return StatsRange(unit: .custom, interval: DateInterval(start: start, end: end))
    }

    /// `true` for day, week, month and year, which have a previous and a next range.
    public var canShift: Bool { unit.calendarComponent != nil }

    /// The range `count` units before (negative) or after (positive) this range.
    public func shifted(by count: Int, calendar: Calendar = .current) -> StatsRange {
        guard let component = unit.calendarComponent,
              let interval,
              let date = calendar.date(byAdding: component, value: count, to: interval.start),
              let shifted = calendar.dateInterval(of: component, for: date) else { return self }
        return StatsRange(unit: unit, interval: shifted)
    }

    public func contains(_ date: Date) -> Bool {
        guard let interval else { return true }
        return date >= interval.start && date < interval.end
    }
}
