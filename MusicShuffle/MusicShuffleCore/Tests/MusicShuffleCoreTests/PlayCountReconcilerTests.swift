import Foundation
import Testing
@testable import MusicShuffleCore

struct PlayCountReconcilerTests {
    let monday = date("2026-11-16T08:00:00Z")
    let tuesday = date("2026-11-17T08:00:00Z")

    @Test func firstCheckRecordsABaseline() {
        let lastPlayed = date("2025-03-01T12:00:00Z")
        let result = PlayCountReconciler.reconcile(
            songs: [song(1, playCount: 12, lastPlayed: lastPlayed), song(2, playCount: 0)],
            previous: [:], now: monday)

        #expect(result.events == [event(song(1, playCount: 12, lastPlayed: lastPlayed),
                                        at: lastPlayed, count: 12, kind: .baseline)])
        #expect(result.snapshots[1] == PlayCountSnapshot(playCount: 12, checkedAt: monday))
        #expect(result.snapshots[2] == PlayCountSnapshot(playCount: 0, checkedAt: monday))
    }

    @Test func noNewPlays() {
        let result = PlayCountReconciler.reconcile(
            songs: [song(1, playCount: 5)],
            previous: [1: PlayCountSnapshot(playCount: 5, checkedAt: monday)], now: tuesday)
        #expect(result.events.isEmpty)
        // No change, so no snapshot to write.
        #expect(result.snapshots.isEmpty)
    }

    @Test func onePlayUsesTheLastPlayedDate() {
        let lastPlayed = date("2026-11-16T20:15:00Z")
        let current = song(1, playCount: 6, lastPlayed: lastPlayed)
        let result = PlayCountReconciler.reconcile(
            songs: [current],
            previous: [1: PlayCountSnapshot(playCount: 5, checkedAt: monday)], now: tuesday)
        #expect(result.events == [event(current, at: lastPlayed, kind: .exact)])
    }

    @Test func morePlaysAreEstimatedBeforeTheLastPlay() {
        let lastPlayed = date("2026-11-16T20:00:00Z")
        let current = song(1, playCount: 8, lastPlayed: lastPlayed)
        let result = PlayCountReconciler.reconcile(
            songs: [current],
            previous: [1: PlayCountSnapshot(playCount: 5, checkedAt: monday)], now: tuesday)
        #expect(result.events == [
            event(current, at: lastPlayed, kind: .exact),
            event(current, at: date("2026-11-16T14:00:00Z"), count: 2, kind: .estimated),
        ])
    }

    @Test(arguments: [nil, date("2026-11-10T00:00:00Z")])
    func playsWithoutAUsableLastPlayedDateAreEstimated(lastPlayed: Date?) {
        let current = song(1, playCount: 7, lastPlayed: lastPlayed)
        let result = PlayCountReconciler.reconcile(
            songs: [current],
            previous: [1: PlayCountSnapshot(playCount: 5, checkedAt: monday)], now: tuesday)
        #expect(result.events == [event(current, at: date("2026-11-16T20:00:00Z"), count: 2, kind: .estimated)])
    }

    @Test func aLowerCountResetsTheSnapshot() {
        let result = PlayCountReconciler.reconcile(
            songs: [song(1, playCount: 2)],
            previous: [1: PlayCountSnapshot(playCount: 9, checkedAt: monday)], now: tuesday)
        #expect(result.events.isEmpty)
        #expect(result.snapshots[1] == PlayCountSnapshot(playCount: 2, checkedAt: tuesday))
    }
}
