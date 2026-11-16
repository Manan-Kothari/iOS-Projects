//
//  MediaLibrary.swift
//  MusicShuffle
//

import MediaPlayer
import MusicShuffleCore

/// Reads the music library off the main thread.
/// A library with tens of thousands of songs can take seconds to read.
enum MediaLibrary {
    /// All songs, or the one song with `id`.
    @concurrent
    nonisolated static func songs(withID id: MPMediaEntityPersistentID? = nil) async -> [LibrarySong] {
        let query = MPMediaQuery.songs()
        if let id {
            query.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: id),
                                                              forProperty: MPMediaItemPropertyPersistentID))
        }
        return (query.items ?? []).map(LibrarySong.init)
    }

    /// The songs of each album, in track order. All albums, or the albums of one artist.
    @concurrent
    nonisolated static func albums(byArtist artistID: MPMediaEntityPersistentID? = nil) async -> sending [[MPMediaItem]] {
        readAlbumCollections(byArtist: artistID).map(\.items)
    }

    @concurrent
    nonisolated static func albumCollections(byArtist artistID: MPMediaEntityPersistentID?) async -> sending [MPMediaItemCollection] {
        readAlbumCollections(byArtist: artistID)
    }

    /// The songs of a playlist, split into albums. The songs in each album keep their playlist order.
    @concurrent
    nonisolated static func albums(inPlaylist playlistID: MPMediaEntityPersistentID) async -> sending [[MPMediaItem]] {
        let query = MPMediaQuery.playlists()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: playlistID),
                                                          forProperty: MPMediaPlaylistPropertyPersistentID))
        let items = query.collections?.first?.items ?? []
        return AlbumQueue<MPMediaItem>.groupedByAlbum(items) { $0.albumPersistentID }
    }

    @concurrent
    nonisolated static func artists() async -> sending [MPMediaItemCollection] {
        MPMediaQuery.artists().collections ?? []
    }

    @concurrent
    nonisolated static func playlists() async -> sending [MPMediaPlaylist] {
        (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }
    }

    private nonisolated static func readAlbumCollections(byArtist artistID: MPMediaEntityPersistentID?) -> [MPMediaItemCollection] {
        let query = MPMediaQuery.albums()
        if let artistID {
            query.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: artistID),
                                                              forProperty: MPMediaItemPropertyArtistPersistentID))
        }
        return query.collections ?? []
    }
}

extension LibrarySong {
    nonisolated init(_ item: MPMediaItem) {
        let artist = item.artist ?? "Unknown Artist"
        self.init(id: item.persistentID,
                  title: item.title ?? "Unknown Title",
                  artist: artist,
                  albumArtist: item.albumArtist ?? artist,
                  albumTitle: item.albumTitle ?? "Unknown Album",
                  playCount: item.playCount,
                  lastPlayedDate: item.lastPlayedDate,
                  duration: item.playbackDuration)
    }
}
