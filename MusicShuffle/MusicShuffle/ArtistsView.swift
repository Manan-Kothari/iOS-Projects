//
//  ArtistsView.swift
//  MusicShuffle
//
//  Created by MMan on 12/14/16.
//  Copyright © 2016 MananKothari. All rights reserved.
//

import MediaPlayer
import SwiftUI

struct ArtistsView: View {
    /// Called after the user starts to play something.
    let onPlay: () -> Void
    @State private var artists: [MPMediaItemCollection]?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filteredArtists, id: \.persistentID) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist, onPlay: onPlay)
                } label: {
                    HStack {
                        ArtworkView(artwork: artist.representativeItem?.artwork)
                        VStack(alignment: .leading) {
                            Text(artist.artistName)
                            Text("^[\(artist.count) song](inflect: true)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Artists")
            .searchable(text: $searchText)
            .overlay {
                if artists == nil {
                    ProgressView()
                } else if artists?.isEmpty == true {
                    ContentUnavailableView("No Artists", systemImage: "music.microphone")
                } else if filteredArtists.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .task {
                artists = await MediaLibrary.artists()
            }
        }
    }

    private var filteredArtists: [MPMediaItemCollection] {
        let artists = artists ?? []
        guard !searchText.isEmpty else { return artists }
        return artists.filter { $0.artistName.localizedStandardContains(searchText) }
    }
}

private struct ArtistDetailView: View {
    @Environment(PlayerModel.self) private var player
    let artist: MPMediaItemCollection
    let onPlay: () -> Void
    @State private var albums: [MPMediaItemCollection] = []

    var body: some View {
        List {
            Section {
                Button("Shuffle Albums", systemImage: "shuffle") {
                    player.shuffle(artist: artist)
                    onPlay()
                }
            }
            Section("Albums") {
                ForEach(albums, id: \.persistentID) { album in
                    Button {
                        player.shuffle(artist: artist, firstAlbum: album.representativeItem?.albumPersistentID)
                        onPlay()
                    } label: {
                        HStack {
                            ArtworkView(artwork: album.representativeItem?.artwork, size: 56)
                            VStack(alignment: .leading) {
                                Text(album.representativeItem?.albumTitle ?? "Unknown Album")
                                    .foregroundStyle(.primary)
                                Text("^[\(album.count) song](inflect: true)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityHint("Plays this album first, then the other albums in a random order")
                }
            }
        }
        .navigationTitle(artist.artistName)
        .task {
            guard let artistID = artist.representativeItem?.artistPersistentID else { return }
            albums = await MediaLibrary.albumCollections(byArtist: artistID)
        }
    }
}

private extension MPMediaItemCollection {
    var artistName: String { representativeItem?.artist ?? "Unknown Artist" }
}
