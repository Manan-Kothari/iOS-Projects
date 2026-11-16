//
//  PlayCountReconciler.swift
//  MusicShuffleCore
//

import Foundation

/// The play count of a song at the time of a check.
public struct PlayCountSnapshot: Hashable, Sendable {
    public var playCount: Int
    public var checkedAt: Date

    public init(playCount: Int, checkedAt: Date) {
        self.playCount = playCount
        self.checkedAt = checkedAt
    }
}

/// Finds new plays by comparing library play counts with the counts from the previous check.
///
/// iOS does not give apps a history of plays. It gives only a total play count and the
/// date of the last play for each song. The play count includes plays from the Music app,
/// so this also finds plays that occurred outside this app.
public enum PlayCountReconciler {
    public struct Result: Sendable {
        public var events: [PlayEvent]
        /// The new snapshot of each song that is new or has a different play count.
        /// Songs with no change keep their snapshot, so a full library check writes few rows.
        public var snapshots: [UInt64: PlayCountSnapshot]
    }

    public static func reconcile(songs: [LibrarySong],
                                 previous: [UInt64: PlayCountSnapshot],
                                 now: Date) -> Result {
        var events: [PlayEvent] = []
        var snapshots: [UInt64: PlayCountSnapshot] = [:]

        for song in songs {
            guard let before = previous[song.id] else {
                // A song seen for the first time. Its plays have no dates, so keep them as a baseline.
                snapshots[song.id] = PlayCountSnapshot(playCount: song.playCount, checkedAt: now)
                if song.playCount > 0 {
                    events.append(PlayEvent(song: song, date: song.lastPlayedDate ?? now,
                                            count: song.playCount, kind: .baseline))
                }
                continue
            }
            guard song.playCount != before.playCount else { continue }
            snapshots[song.id] = PlayCountSnapshot(playCount: song.playCount, checkedAt: now)

            // A lower count means the library was reset. The new count becomes the reference.
            let newPlays = song.playCount - before.playCount
            if newPlays > 0 {
                events += playEvents(for: song, count: newPlays, since: before.checkedAt, now: now)
            }
        }
        return Result(events: events, snapshots: snapshots)
    }

    private static func playEvents(for song: LibrarySong, count: Int, since: Date, now: Date) -> [PlayEvent] {
        // The last played date is exact for the most recent play only.
        if let lastPlayed = song.lastPlayedDate, lastPlayed > since, lastPlayed <= now {
            var events = [PlayEvent(song: song, date: lastPlayed, count: 1, kind: .exact)]
            if count > 1 {
                events.append(PlayEvent(song: song, date: midpoint(since, lastPlayed),
                                        count: count - 1, kind: .estimated))
            }
            return events
        }
        return [PlayEvent(song: song, date: midpoint(since, now), count: count, kind: .estimated)]
    }

    private static func midpoint(_ start: Date, _ end: Date) -> Date {
        start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }
}
