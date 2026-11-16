//
//  PlayHistoryStore.swift
//  MusicShuffleCore
//

import Foundation
import SwiftData

@Model
final class PlayRecord {
    #Index<PlayRecord>([\.date])

    var songID: Int64
    var title: String
    var artist: String
    var albumArtist: String
    var albumTitle: String
    var date: Date
    var count: Int
    var duration: TimeInterval
    var kindRaw: String

    init(_ event: PlayEvent) {
        songID = Int64(bitPattern: event.songID)
        title = event.title
        artist = event.artist
        albumArtist = event.albumArtist
        albumTitle = event.albumTitle
        date = event.date
        count = event.count
        duration = event.duration
        kindRaw = event.kind.rawValue
    }

    var event: PlayEvent {
        PlayEvent(songID: UInt64(bitPattern: songID),
                  title: title,
                  artist: artist,
                  albumArtist: albumArtist,
                  albumTitle: albumTitle,
                  date: date,
                  count: count,
                  duration: duration,
                  kind: PlayEvent.Kind(rawValue: kindRaw) ?? .estimated)
    }
}

/// The play count of a song when it last changed.
@Model
final class SongSnapshot {
    #Unique<SongSnapshot>([\.songID])

    var songID: Int64
    var playCount: Int
    var checkedAt: Date

    init(songID: Int64, playCount: Int, checkedAt: Date) {
        self.songID = songID
        self.playCount = playCount
        self.checkedAt = checkedAt
    }
}

/// The date of the most recent full library check. There is one row at most.
@Model
final class LibraryCheck {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}

/// Keeps the play history and the play count snapshots on disk.
///
/// The store is an actor with its own model context, so its work runs off the main thread.
/// Create it off the main thread too (for example in a detached task). A model context
/// that is made on the main thread can run its work on the main thread.
public actor PlayHistoryStore: ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer

    static let schema = Schema([PlayRecord.self, SongSnapshot.self, LibraryCheck.self])

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration("PlayHistory", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    public init(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
    }

    /// Compares the play counts of `songs` with the last check and saves the new plays.
    /// - Parameter isFullLibrary: `true` when `songs` is the whole library. The store then
    ///   records the check date once, instead of a new date for each song.
    /// - Returns: The new plays.
    @discardableResult
    public func reconcile(_ songs: [LibrarySong], isFullLibrary: Bool = false, now: Date = .now) throws -> [PlayEvent] {
        guard !songs.isEmpty else { return [] }
        let lastFullCheck = try fetchLastFullCheck()
        let existing = try snapshots(for: songs)
        // A song was last checked at its own snapshot date or at the last full check, whichever is later.
        let previous = existing.mapValues { record in
            PlayCountSnapshot(playCount: record.playCount,
                              checkedAt: max(record.checkedAt, lastFullCheck?.date ?? .distantPast))
        }
        let result = PlayCountReconciler.reconcile(songs: songs, previous: previous, now: now)

        for event in result.events {
            modelContext.insert(PlayRecord(event))
        }
        for (songID, snapshot) in result.snapshots {
            if let record = existing[songID] {
                record.playCount = snapshot.playCount
                record.checkedAt = snapshot.checkedAt
            } else {
                modelContext.insert(SongSnapshot(songID: Int64(bitPattern: songID),
                                                 playCount: snapshot.playCount,
                                                 checkedAt: snapshot.checkedAt))
            }
        }
        if isFullLibrary {
            if let lastFullCheck {
                lastFullCheck.date = now
            } else {
                modelContext.insert(LibraryCheck(date: now))
            }
        }
        try modelContext.save()
        return result.events
    }

    public func events(in range: StatsRange) throws -> [PlayEvent] {
        var descriptor = FetchDescriptor<PlayRecord>(sortBy: [SortDescriptor(\.date)])
        if let interval = range.interval {
            let start = interval.start
            let end = interval.end
            let baseline = PlayEvent.Kind.baseline.rawValue
            descriptor.predicate = #Predicate { $0.date >= start && $0.date < end && $0.kindRaw != baseline }
        }
        return try modelContext.fetch(descriptor).map(\.event)
    }

    public func statistics(for range: StatsRange, calendar: Calendar = .current) throws -> PlayStatistics {
        PlayStatistics(events: try events(in: range), range: range, calendar: calendar)
    }

    private func fetchLastFullCheck() throws -> LibraryCheck? {
        var descriptor = FetchDescriptor<LibraryCheck>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func snapshots(for songs: [LibrarySong]) throws -> [UInt64: SongSnapshot] {
        var descriptor = FetchDescriptor<SongSnapshot>()
        // A full library check reads all snapshots. A small check reads only the songs it needs.
        if songs.count <= 100 {
            let ids = songs.map { Int64(bitPattern: $0.id) }
            descriptor.predicate = #Predicate { ids.contains($0.songID) }
        }
        let records = try modelContext.fetch(descriptor)
        return Dictionary(records.map { (UInt64(bitPattern: $0.songID), $0) }, uniquingKeysWith: { first, _ in first })
    }
}
