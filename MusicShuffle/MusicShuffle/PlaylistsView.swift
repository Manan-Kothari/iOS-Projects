//
//  PlaylistsView.swift
//  MusicShuffle
//
//  Created by MMan on 12/14/16.
//  Copyright © 2016 MananKothari. All rights reserved.
//

import MediaPlayer
import SwiftUI

struct PlaylistsView: View {
    /// Called after the user starts to play something.
    let onPlay: () -> Void
    @State private var playlists: [MPMediaPlaylist]?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filteredPlaylists, id: \.persistentID) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist, onPlay: onPlay)
                } label: {
                    HStack {
                        ArtworkView(artwork: playlist.representativeItem?.artwork)
                        VStack(alignment: .leading) {
                            Text(playlist.name ?? "Untitled Playlist")
                            Text("^[\(playlist.count) song](inflect: true)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .searchable(text: $searchText)
            .overlay {
                if playlists == nil {
                    ProgressView()
                } else if playlists?.isEmpty == true {
                    ContentUnavailableView("No Playlists", systemImage: "music.note.list")
                } else if filteredPlaylists.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .task {
                playlists = await MediaLibrary.playlists()
            }
        }
    }

    private var filteredPlaylists: [MPMediaPlaylist] {
        let playlists = playlists ?? []
        guard !searchText.isEmpty else { return playlists }
        return playlists.filter { ($0.name ?? "").localizedStandardContains(searchText) }
    }
}

private struct PlaylistDetailView: View {
    @Environment(PlayerModel.self) private var player
    let playlist: MPMediaPlaylist
    let onPlay: () -> Void

    var body: some View {
        List {
            Section {
                Button("Shuffle by Album", systemImage: "shuffle") {
                    player.shuffle(playlist: playlist)
                    onPlay()
                }
                .disabled(playlist.items.isEmpty)
            } footer: {
                Text("Plays the albums in this playlist in a random order. The songs of each album stay together in playlist order.")
            }
            Section("Songs") {
                ForEach(playlist.items, id: \.persistentID) { item in
                    HStack {
                        ArtworkView(artwork: item.artwork)
                        VStack(alignment: .leading) {
                            Text(item.title ?? "Unknown Title")
                            Text("\(item.artist ?? "Unknown Artist") · \(item.albumTitle ?? "Unknown Album")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle(playlist.name ?? "Playlist")
    }
}
