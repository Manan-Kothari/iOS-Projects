import Foundation
import SwiftData
import Testing
@testable import MusicShuffleCore

struct PlayHistoryStoreTests {
    let container = try! PlayHistoryStore.makeContainer(inMemory: true)
    let store: PlayHistoryStore

    let monday = date("2026-11-16T08:00:00Z")
    let tuesday = date("2026-11-17T08:00:00Z")
    let wednesday = date("2026-11-18T08:00:00Z")

    init() {
        store = PlayHistoryStore(modelContainer: container)
    }

    @Test func savesPlaysFoundBetweenChecks() async throws {
        let lastPlayed = date("2026-11-16T21:00:00Z")
        try await store.reconcile([song(1, playCount: 10), song(2, playCount: 0)], isFullLibrary: true, now: monday)
        let newPlays = try await store.reconcile([song(1, playCount: 12, lastPlayed: lastPlayed), song(2, playCount: 1)],
                                                 isFullLibrary: true, now: tuesday)

        #expect(newPlays.map(\.count).reduce(0, +) == 3)
        let week = StatsRange.current(.week, now: tuesday, calendar: utcCalendar)
        let stats = try await store.statistics(for: week, calendar: utcCalendar)
        #expect(stats.totalPlays == 3)
        #expect(stats.topSongs.map(\.title) == ["Song 1", "Song 2"])

        let allTime = try await store.statistics(for: .current(.allTime), calendar: utcCalendar)
        #expect(allTime.totalPlays == 13)
    }

    @Test func doesNotCountTheSamePlaysTwice() async throws {
        try await store.reconcile([song(1, playCount: 3)], now: monday)
        try await store.reconcile([song(1, playCount: 4)], now: tuesday)
        let again = try await store.reconcile([song(1, playCount: 4)], now: date("2026-11-17T09:00:00Z"))

        #expect(again.isEmpty)
        #expect(try await store.events(in: .current(.allTime)).map(\.count) == [3, 1])
    }

    @Test func aSmallCheckUpdatesOnlyItsSongs() async throws {
        try await store.reconcile((1...150).map { song(UInt64($0), playCount: 1) }, isFullLibrary: true, now: monday)
        // The single-song check after a song ends.
        try await store.reconcile([song(42, playCount: 2)], now: tuesday)
        // A full check later must not count song 42 again.
        try await store.reconcile((1...150).map { song(UInt64($0), playCount: $0 == 42 ? 2 : 1) },
                                  isFullLibrary: true, now: wednesday)

        let week = try await store.events(in: .current(.week, now: tuesday, calendar: utcCalendar))
        #expect(week.count == 1)
        #expect(week.first?.songID == 42)
    }

    @Test func estimatesFromTheLastFullCheckWhenTheCountDidNotChange() async throws {
        try await store.reconcile([song(1, playCount: 1)], isFullLibrary: true, now: monday)
        // No change, so the snapshot row keeps Monday. The full check date moves to Tuesday.
        try await store.reconcile([song(1, playCount: 1)], isFullLibrary: true, now: tuesday)
        let newPlays = try await store.reconcile([song(1, playCount: 2)], isFullLibrary: true, now: wednesday)

        // The play occurred between Tuesday and Wednesday, not between Monday and Wednesday.
        #expect(newPlays.map(\.date) == [date("2026-11-17T20:00:00Z")])
    }

    @Test func keepsDataInTheContainer() async throws {
        try await store.reconcile([song(UInt64.max, playCount: 1)], now: monday)
        try await store.reconcile([song(UInt64.max, playCount: 2)], now: tuesday)

        // A new store on the same container reads the saved data. The ID round-trips through Int64.
        let events = try await PlayHistoryStore(modelContainer: container).events(in: .current(.allTime))
        #expect(events.map(\.songID) == [UInt64.max, UInt64.max])
    }

    @Test(.timeLimit(.minutes(1)))
    func handlesALargeLibrary() async throws {
        let songCount = 30_000
        let library = (1...songCount).map { song(UInt64($0), artist: "Artist \($0 % 900)", playCount: $0 % 20) }
        let changed = library.map { song in
            var song = song
            if song.id % 150 == 0 {
                song.playCount += 1
            }
            return song
        }
        let clock = ContinuousClock()

        let first = try await clock.measure {
            try await store.reconcile(library, isFullLibrary: true, now: monday)
        }
        let unchanged = try await clock.measure {
            let newPlays = try await store.reconcile(library, isFullLibrary: true, now: tuesday)
            #expect(newPlays.isEmpty)
        }
        let someChanged = try await clock.measure {
            let newPlays = try await store.reconcile(changed, isFullLibrary: true, now: wednesday)
            #expect(newPlays.count == songCount / 150)
        }
        let stats = try await clock.measure {
            let allTime = try await store.statistics(for: .current(.allTime), calendar: utcCalendar)
            #expect(allTime.totalPlays == library.reduce(0) { $0 + $1.playCount } + songCount / 150)
        }
        print("30,000 songs: first check \(first), no change \(unchanged), 200 changed \(someChanged), all-time stats \(stats)")
    }
}
