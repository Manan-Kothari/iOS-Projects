//
//  AlbumQueue.swift
//  MusicShuffleCore
//
//  Copyright © 2016 MananKothari. All rights reserved.
//

/// A play queue made of whole albums in a random order.
/// The songs in each album keep the order they were given in.
///
/// The queue records where each album starts, so "next album" and "previous album"
/// are lookups and do not depend on the track number metadata of the songs.
public struct AlbumQueue<Song> {
    /// All songs, one album after the other.
    public let songs: [Song]
    /// The index in `songs` of the first song of each album, in queue order.
    public let albumStartIndices: [Int]

    /// - Parameter firstAlbum: The index in `albums` of an album to play first.
    ///   The other albums follow in a random order.
    public init<Generator: RandomNumberGenerator>(albums: [[Song]],
                                                  firstAlbum: Int? = nil,
                                                  using generator: inout Generator) {
        var ordered = albums
        var first: [Song]?
        if let firstAlbum, ordered.indices.contains(firstAlbum) {
            first = ordered.remove(at: firstAlbum)
        }
        ordered.shuffle(using: &generator)
        if let first {
            ordered.insert(first, at: 0)
        }

        var songs: [Song] = []
        var albumStartIndices: [Int] = []
        for album in ordered where !album.isEmpty {
            albumStartIndices.append(songs.count)
            songs.append(contentsOf: album)
        }
        self.songs = songs
        self.albumStartIndices = albumStartIndices
    }

    public init(albums: [[Song]], firstAlbum: Int? = nil) {
        var generator = SystemRandomNumberGenerator()
        self.init(albums: albums, firstAlbum: firstAlbum, using: &generator)
    }

    /// Splits `songs` into albums. The albums are in the order of their first song,
    /// and the songs in each album keep their order from `songs`.
    public static func groupedByAlbum<Key: Hashable>(_ songs: [Song], albumKey: (Song) -> Key) -> [[Song]] {
        var keys: [Key] = []
        var albums: [Key: [Song]] = [:]
        for song in songs {
            let key = albumKey(song)
            if albums[key] == nil {
                keys.append(key)
            }
            albums[key, default: []].append(song)
        }
        return keys.map { albums[$0] ?? [] }
    }

    public var isEmpty: Bool { songs.isEmpty }

    public var albumCount: Int { albumStartIndices.count }

    /// The indices in `songs` of the songs of the album at position `album` in the queue.
    public func songIndices(ofAlbumAt album: Int) -> Range<Int>? {
        guard albumStartIndices.indices.contains(album) else { return nil }
        let end = album + 1 < albumCount ? albumStartIndices[album + 1] : songs.count
        return albumStartIndices[album]..<end
    }

    /// The position in the queue of the album that contains the song at `songIndex`.
    public func albumIndex(containingSongAt songIndex: Int) -> Int? {
        guard songs.indices.contains(songIndex) else { return nil }
        // Find the last album that starts at or before `songIndex`.
        var low = 0
        var high = albumStartIndices.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if albumStartIndices[mid] <= songIndex {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    /// The index of the first song of the album after the one that contains
    /// the song at `songIndex`. After the last album, this wraps to the first album.
    public func startOfNextAlbum(afterSongAt songIndex: Int) -> Int? {
        guard let album = albumIndex(containingSongAt: songIndex) else { return nil }
        return albumStartIndices[(album + 1) % albumCount]
    }

    /// The index of the first song of the album before the one that contains
    /// the song at `songIndex`. Before the first album, this wraps to the last album.
    public func startOfPreviousAlbum(beforeSongAt songIndex: Int) -> Int? {
        guard let album = albumIndex(containingSongAt: songIndex) else { return nil }
        return albumStartIndices[(album - 1 + albumCount) % albumCount]
    }
}

extension AlbumQueue: Sendable where Song: Sendable {}
