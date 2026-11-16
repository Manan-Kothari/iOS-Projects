//
//  ContentView.swift
//  MusicShuffle
//

import MediaPlayer
import SwiftUI

enum AppTab: Hashable {
    case nowPlaying, artists, playlists, stats, settings
}

struct ContentView: View {
    let libraryAccess: MPMediaLibraryAuthorizationStatus
    @State private var selectedTab = AppTab.nowPlaying

    var body: some View {
        switch libraryAccess {
        case .authorized:
            TabView(selection: $selectedTab) {
                Tab("Now Playing", systemImage: "play.circle", value: .nowPlaying) {
                    NowPlayingView()
                }
                Tab("Artists", systemImage: "music.microphone", value: .artists) {
                    ArtistsView { selectedTab = .nowPlaying }
                }
                Tab("Playlists", systemImage: "music.note.list", value: .playlists) {
                    PlaylistsView { selectedTab = .nowPlaying }
                }
                Tab("Stats", systemImage: "chart.bar", value: .stats) {
                    StatsView()
                }
                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }
        case .notDetermined:
            ProgressView()
        default:
            ContentUnavailableView {
                Label("No Access to Music", systemImage: "music.note")
            } description: {
                Text("MusicShuffle needs access to your music library to play and count your music.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

/// The artwork of a song, or a placeholder when the song has no artwork.
struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image = artwork?.image(at: CGSize(width: size * 3, height: size * 3)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size / 10))
        .accessibilityHidden(true)
    }
}
