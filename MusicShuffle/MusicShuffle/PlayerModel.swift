//
//  PlayerModel.swift
//  MusicShuffle
//
//  Created by MMan on 8/5/16.
//  Copyright © 2016 MananKothari. All rights reserved.
//

import MediaPlayer
import MusicShuffleCore
import Observation

/// Plays the music library as whole albums in a random order.
@Observable
final class PlayerModel {
    private(set) var nowPlaying: MPMediaItem?
    private(set) var isPlaying = false
    /// The name of what the queue plays, for example "Library" or an artist name.
    private(set) var queueTitle: String?
    /// The position of the current album in the queue, from 1. `nil` when the current song is not in our queue.
    private(set) var albumNumber: Int?
    /// `true` while the albums for a new queue are read from the library.
    private(set) var isLoadingQueue = false
    var albumCount: Int { queue.albumCount }

    /// Called with the previous song when the now playing song changes.
    @ObservationIgnored var onSongChanged: ((MPMediaItem) -> Void)?

    // The system player keeps playing when the app is in the background. It shares its
    // queue and shuffle mode with the Music app, so the shuffle mode is set after each new queue.
    @ObservationIgnored private let player = MPMusicPlayerController.systemMusicPlayer
    // Observed, so that the queue screen updates when a new queue starts.
    private var queue = AlbumQueue<MPMediaItem>(albums: [])
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
                               object: player, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.nowPlayingItemChanged() }
            },
            center.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange,
                               object: player, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.playbackStateChanged() }
            },
        ]
        player.beginGeneratingPlaybackNotifications()
        nowPlaying = player.nowPlayingItem
        isPlaying = player.playbackState == .playing
    }

    /// The playback position of the current song. Read it from a `TimelineView`, because it is not observed.
    var currentTime: TimeInterval {
        let time = player.currentPlaybackTime
        return time.isFinite ? time : 0
    }

    // MARK: - Queues

    /// Makes a new album shuffle of the whole library. It does not replace a song that is playing.
    func prepareLibraryShuffle() {
        loadQueue(title: "Library", play: false) { await MediaLibrary.albums() }
    }

    func shuffleLibrary() {
        loadQueue(title: "Library", play: true) { await MediaLibrary.albums() }
    }

    /// Plays the albums of an artist in a random order.
    /// - Parameter firstAlbum: An album to play first.
    func shuffle(artist: MPMediaItemCollection, firstAlbum: MPMediaEntityPersistentID? = nil) {
        guard let artistItem = artist.representativeItem else { return }
        let artistID = artistItem.artistPersistentID
        loadQueue(title: artistItem.artist ?? "Unknown Artist", play: true, firstAlbum: firstAlbum) {
            await MediaLibrary.albums(byArtist: artistID)
        }
    }

    /// Plays the songs of a playlist as albums in a random order.
    /// The songs in each album keep their playlist order.
    func shuffle(playlist: MPMediaPlaylist) {
        let playlistID = playlist.persistentID
        loadQueue(title: playlist.name ?? "Playlist", play: true) {
            await MediaLibrary.albums(inPlaylist: playlistID)
        }
    }

    /// Reads the albums off the main thread, then starts the queue. A new request cancels an earlier one.
    private func loadQueue(title: String,
                           play: Bool,
                           firstAlbum: MPMediaEntityPersistentID? = nil,
                           albums readAlbums: @escaping @MainActor () async -> [[MPMediaItem]]) {
        loadTask?.cancel()
        isLoadingQueue = true
        loadTask = Task {
            let albums = await readAlbums()
            guard !Task.isCancelled else { return }
            isLoadingQueue = false
            // Do not replace a song that started to play while the albums were read.
            guard play || !isPlaying else { return }
            let first = firstAlbum.flatMap { id in albums.firstIndex { $0.first?.albumPersistentID == id } }
            startQueue(albums: albums, firstAlbum: first, title: title, play: play)
        }
    }

    private func startQueue(albums: [[MPMediaItem]], firstAlbum: Int?, title: String, play: Bool) {
        let newQueue = AlbumQueue(albums: albums, firstAlbum: firstAlbum)
        guard !newQueue.isEmpty else { return }
        queue = newQueue
        queueTitle = title

        player.setQueue(with: MPMediaItemCollection(items: queue.songs))
        //The queue order is the shuffle, so turn off the player's own shuffle
        player.shuffleMode = .off
        player.repeatMode = .all
        player.nowPlayingItem = queue.songs[0]
        if play {
            player.play()
        } else {
            player.prepareToPlay()
        }
        nowPlayingItemChanged()
    }

    // MARK: - Controls

    func playPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func nextSong() {
        player.skipToNextItem()
    }

    /// Goes to the start of the song. Near the start, goes to the previous song.
    func previousSong() {
        if currentTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
        }
    }

    func nextAlbum() {
        guard let current = currentSongIndex(),
              let next = queue.startOfNextAlbum(afterSongAt: current) else { return }
        player.nowPlayingItem = queue.songs[next]
        player.play()
    }

    func previousAlbum() {
        guard let current = currentSongIndex(),
              let previous = queue.startOfPreviousAlbum(beforeSongAt: current) else { return }
        player.nowPlayingItem = queue.songs[previous]
        player.play()
    }

    /// Plays the album at position `album` in the queue (from 0), then continues with the albums after it.
    func playAlbum(at album: Int) {
        guard let songs = queue.songIndices(ofAlbumAt: album) else { return }
        player.nowPlayingItem = queue.songs[songs.lowerBound]
        player.play()
    }

    /// The first song and the number of songs of the album at position `album` in the queue (from 0).
    func queueAlbum(at album: Int) -> (firstSong: MPMediaItem, songCount: Int)? {
        guard let songs = queue.songIndices(ofAlbumAt: album) else { return nil }
        return (queue.songs[songs.lowerBound], songs.count)
    }

    func seek(to time: TimeInterval) {
        player.currentPlaybackTime = time
    }

    // MARK: - Player state

    //The index of the now playing item in queue.songs.
    //The Music app can change the system queue, so check that the item at the player's index is the same song.
    private func currentSongIndex() -> Int? {
        guard let item = player.nowPlayingItem else { return nil }
        let index = player.indexOfNowPlayingItem
        if queue.songs.indices.contains(index), queue.songs[index].persistentID == item.persistentID {
            return index
        }
        return queue.songs.firstIndex { $0.persistentID == item.persistentID }
    }

    private func nowPlayingItemChanged() {
        let previous = nowPlaying
        nowPlaying = player.nowPlayingItem
        albumNumber = currentSongIndex().flatMap { queue.albumIndex(containingSongAt: $0) }.map { $0 + 1 }
        if let previous, previous.persistentID != nowPlaying?.persistentID {
            onSongChanged?(previous)
        }
    }

    private func playbackStateChanged() {
        isPlaying = player.playbackState == .playing
    }
}
