//
//  QueueView.swift
//  MusicShuffle
//

import MediaPlayer
import SwiftUI

/// The albums of the queue in play order. Tap an album to play from it.
struct QueueView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(visibleAlbums, id: \.self) { album in
                    if let info = player.queueAlbum(at: album) {
                        row(album: album, firstSong: info.firstSong, songCount: info.songCount)
                    }
                }
                .onAppear {
                    if let current = player.albumNumber {
                        proxy.scrollTo(current - 1, anchor: .center)
                    }
                }
            }
            .navigationTitle(player.queueTitle ?? "Queue")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Album or Artist")
            .toolbar {
                Button("Done", systemImage: "checkmark") { dismiss() }
            }
            .overlay {
                if player.albumCount == 0 {
                    ContentUnavailableView("No Queue", systemImage: "list.bullet",
                                           description: Text("Shuffle the library, an artist or a playlist to make a queue."))
                } else if visibleAlbums.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    /// The album positions to show (from 0). All albums, or the albums that match the search.
    private var visibleAlbums: [Int] {
        let all = Array(0..<player.albumCount)
        guard !searchText.isEmpty else { return all }
        return all.filter { album in
            guard let song = player.queueAlbum(at: album)?.firstSong else { return false }
            return [song.albumTitle, song.albumArtist, song.artist].contains {
                $0?.localizedStandardContains(searchText) == true
            }
        }
    }

    private func row(album: Int, firstSong: MPMediaItem, songCount: Int) -> some View {
        let isCurrent = album + 1 == player.albumNumber
        return Button {
            player.playAlbum(at: album)
            dismiss()
        } label: {
            HStack {
                Text("\(album + 1)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, alignment: .trailing)
                ArtworkView(artwork: firstSong.artwork, size: 48)
                VStack(alignment: .leading) {
                    Text(firstSong.albumTitle ?? "Unknown Album")
                        .foregroundStyle(.primary)
                    Text("\(firstSong.albumArtist ?? firstSong.artist ?? "Unknown Artist") · ^[\(songCount) song](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer()
                if isCurrent {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Now playing")
                }
            }
        }
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : nil)
        .accessibilityHint("Plays this album, then continues with the albums after it")
    }
}
