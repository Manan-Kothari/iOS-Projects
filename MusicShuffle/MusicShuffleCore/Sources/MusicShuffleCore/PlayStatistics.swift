//
//  PlayStatistics.swift
//  MusicShuffleCore
//

import Foundation

/// A song, artist or album with its play totals.
public struct RankedItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let plays: Int
    public let listeningTime: TimeInterval
}

public struct TimelineBucket: Identifiable, Hashable, Sendable {
    public var id: Date { start }
    public let start: Date
    public let plays: Int
}

/// Play totals and top lists for one time range.
public struct PlayStatistics: Equatable, Sendable {
    public let range: StatsRange
    public let totalPlays: Int
    /// The plays that have an estimated date.
    public let estimatedPlays: Int
    public let listeningTime: TimeInterval
    public let topSongs: [RankedItem]
    public let topArtists: [RankedItem]
    public let topAlbums: [RankedItem]
    /// Plays per `timelineComponent`. Baseline plays have no real date, so they are not in the timeline.
    public let timeline: [TimelineBucket]
    public let timelineComponent: Calendar.Component

    /// - Parameter limit: The maximum number of items in each top list.
    public init(events: [PlayEvent], range: StatsRange, calendar: Calendar = .current, limit: Int = 25) {
        let events = events.filter { range.interval == nil || ($0.kind != .baseline && range.contains($0.date)) }
        let datedEvents = events.filter { $0.kind != .baseline }

        self.range = range
        totalPlays = events.reduce(0) { $0 + $1.count }
        estimatedPlays = events.filter { $0.kind == .estimated }.reduce(0) { $0 + $1.count }
        listeningTime = events.reduce(0) { $0 + $1.listeningTime }

        topSongs = Self.rank(events, limit: limit) {
            (String($0.songID), $0.title, "\($0.artist) · \($0.albumTitle)")
        }
        topArtists = Self.rank(events, limit: limit) { ($0.artist, $0.artist, nil) }
        topAlbums = Self.rank(events, limit: limit) {
            ("\($0.albumArtist)\u{1F}\($0.albumTitle)", $0.albumTitle, $0.albumArtist)
        }

        let component = Self.timelineComponent(for: range, events: datedEvents)
        timelineComponent = component
        var buckets: [Date: Int] = [:]
        for event in datedEvents {
            let start = calendar.dateInterval(of: component, for: event.date)?.start ?? event.date
            buckets[start, default: 0] += event.count
        }
        timeline = buckets.map { TimelineBucket(start: $0.key, plays: $0.value) }.sorted { $0.start < $1.start }
    }

    private static func rank(_ events: [PlayEvent],
                             limit: Int,
                             by describe: (PlayEvent) -> (key: String, title: String, subtitle: String?)) -> [RankedItem] {
        var totals: [String: (title: String, subtitle: String?, plays: Int, time: TimeInterval)] = [:]
        for event in events {
            let (key, title, subtitle) = describe(event)
            var total = totals[key] ?? (title, subtitle, 0, 0)
            total.plays += event.count
            total.time += event.listeningTime
            totals[key] = total
        }
        let items = totals.map {
            RankedItem(id: $0.key, title: $0.value.title, subtitle: $0.value.subtitle,
                       plays: $0.value.plays, listeningTime: $0.value.time)
        }
        return Array(items.sorted {
            if $0.plays != $1.plays { return $0.plays > $1.plays }
            if $0.listeningTime != $1.listeningTime { return $0.listeningTime > $1.listeningTime }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }.prefix(limit))
    }

    static func timelineComponent(for range: StatsRange, events: [PlayEvent]) -> Calendar.Component {
        switch range.unit {
        case .day: return .hour
        case .week, .month: return .day
        case .year: return .month
        case .allTime, .custom:
            let span: TimeInterval
            if let interval = range.interval {
                span = interval.duration
            } else if let first = events.map(\.date).min(), let last = events.map(\.date).max() {
                span = last.timeIntervalSince(first)
            } else {
                span = 0
            }
            let day: TimeInterval = 24 * 60 * 60
            switch span {
            case ...(2 * day): return .hour
            case ...(62 * day): return .day
            case ...(3 * 366 * day): return .month
            default: return .year
            }
        }
    }
}
