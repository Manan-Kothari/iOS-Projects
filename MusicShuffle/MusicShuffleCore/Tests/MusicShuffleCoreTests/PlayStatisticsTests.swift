import Foundation
import Testing
@testable import MusicShuffleCore

struct PlayStatisticsTests {
    let rock = song(1, title: "Rock Song", artist: "Band", album: "Loud", playCount: 0, duration: 200)
    let rock2 = song(2, title: "Rock Song 2", artist: "Band", album: "Loud", playCount: 0, duration: 100)
    let jazz = song(3, title: "Jazz Song", artist: "Trio", album: "Smooth", playCount: 0, duration: 300)

    var events: [PlayEvent] {
        [
            event(rock, at: date("2026-11-16T09:00:00Z"), count: 3),
            event(rock2, at: date("2026-11-17T09:00:00Z"), kind: .estimated),
            event(jazz, at: date("2026-11-17T22:00:00Z"), count: 2),
            // Last week.
            event(jazz, at: date("2026-11-10T09:00:00Z"), count: 5),
            // Plays from before tracking started.
            event(rock2, at: date("2026-11-17T10:00:00Z"), count: 40, kind: .baseline),
        ]
    }

    @Test func weekTotalsAndRankings() {
        let week = StatsRange.current(.week, now: date("2026-11-18T12:00:00Z"), calendar: utcCalendar)
        let stats = PlayStatistics(events: events, range: week, calendar: utcCalendar)

        #expect(stats.totalPlays == 6)
        #expect(stats.estimatedPlays == 1)
        #expect(stats.listeningTime == 3 * 200 + 100 + 2 * 300)
        #expect(stats.topSongs.map(\.title) == ["Rock Song", "Jazz Song", "Rock Song 2"])
        #expect(stats.topArtists.map(\.title) == ["Band", "Trio"])
        #expect(stats.topArtists.map(\.plays) == [4, 2])
        #expect(stats.topAlbums.first?.title == "Loud")
        #expect(stats.topAlbums.first?.subtitle == "Band")
        #expect(stats.timelineComponent == .day)
        #expect(stats.timeline == [
            TimelineBucket(start: date("2026-11-16T00:00:00Z"), plays: 3),
            TimelineBucket(start: date("2026-11-17T00:00:00Z"), plays: 3),
        ])
    }

    @Test func allTimeIncludesTheBaselineButNotInTheTimeline() {
        let stats = PlayStatistics(events: events, range: .current(.allTime), calendar: utcCalendar)
        #expect(stats.totalPlays == 51)
        #expect(stats.topSongs.first?.title == "Rock Song 2")
        #expect(stats.topSongs.first?.plays == 41)
        #expect(stats.timeline.reduce(0) { $0 + $1.plays } == 11)
    }

    @Test func equalPlaysRankByListeningTimeThenTitle() {
        let a = song(10, title: "B", playCount: 0, duration: 100)
        let b = song(11, title: "A", playCount: 0, duration: 100)
        let c = song(12, title: "C", playCount: 0, duration: 500)
        let now = date("2026-11-18T12:00:00Z")
        let stats = PlayStatistics(events: [event(a, at: now), event(b, at: now), event(c, at: now)],
                                   range: .current(.day, now: now, calendar: utcCalendar), calendar: utcCalendar)
        #expect(stats.topSongs.map(\.title) == ["C", "A", "B"])
        #expect(stats.timelineComponent == .hour)
    }

    @Test func limitsTheTopLists() {
        let now = date("2026-11-18T12:00:00Z")
        let many = (100..<140).map { event(song(UInt64($0), artist: "Artist \($0)", playCount: 0), at: now) }
        let stats = PlayStatistics(events: many, range: .current(.year, now: now, calendar: utcCalendar),
                                   calendar: utcCalendar, limit: 10)
        #expect(stats.topSongs.count == 10)
        #expect(stats.topArtists.count == 10)
        #expect(stats.totalPlays == 40)
        #expect(stats.timelineComponent == .month)
    }

    @Test(arguments: [
        (1, Calendar.Component.hour),
        (30, .day),
        (365, .month),
        (5 * 365, .year),
    ])
    func customTimelineComponentFollowsTheSpan(days: Int, component: Calendar.Component) {
        let start = date("2020-01-01T00:00:00Z")
        let end = utcCalendar.date(byAdding: .day, value: days - 1, to: start)!
        let range = StatsRange.custom(from: start, through: end, calendar: utcCalendar)
        #expect(PlayStatistics(events: [], range: range, calendar: utcCalendar).timelineComponent == component)
    }
}
