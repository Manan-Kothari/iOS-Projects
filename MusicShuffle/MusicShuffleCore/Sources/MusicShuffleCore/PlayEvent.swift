//
//  PlayEvent.swift
//  MusicShuffleCore
//

import Foundation

/// A song in the music library, with the play data that the library keeps.
public struct LibrarySong: Hashable, Sendable {
    public var id: UInt64
    public var title: String
    public var artist: String
    public var albumArtist: String
    public var albumTitle: String
    /// The total number of plays, from this app, the Music app, and synced devices.
    public var playCount: Int
    /// The date of the most recent play. The library does not keep older play dates.
    public var lastPlayedDate: Date?
    public var duration: TimeInterval

    public init(id: UInt64,
                title: String,
                artist: String,
                albumArtist: String,
                albumTitle: String,
                playCount: Int,
                lastPlayedDate: Date?,
                duration: TimeInterval) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
        self.duration = duration
    }
}

/// One or more plays of a song at one date.
public struct PlayEvent: Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        /// The date is the last played date from the library.
        case exact
        /// The plays occurred between two play count checks.
        /// The date is the middle of that interval.
        case estimated
        /// Plays from before the app started to track the song.
        /// These plays count toward all-time totals only.
        case baseline
    }

    public var songID: UInt64
    public var title: String
    public var artist: String
    public var albumArtist: String
    public var albumTitle: String
    public var date: Date
    public var count: Int
    /// The length of one play of the song.
    public var duration: TimeInterval
    public var kind: Kind

    public init(songID: UInt64,
                title: String,
                artist: String,
                albumArtist: String,
                albumTitle: String,
                date: Date,
                count: Int,
                duration: TimeInterval,
                kind: Kind) {
        self.songID = songID
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        self.date = date
        self.count = count
        self.duration = duration
        self.kind = kind
    }

    public init(song: LibrarySong, date: Date, count: Int, kind: Kind) {
        self.init(songID: song.id,
                  title: song.title,
                  artist: song.artist,
                  albumArtist: song.albumArtist,
                  albumTitle: song.albumTitle,
                  date: date,
                  count: count,
                  duration: song.duration,
                  kind: kind)
    }

    public var listeningTime: TimeInterval { duration * Double(count) }
}
