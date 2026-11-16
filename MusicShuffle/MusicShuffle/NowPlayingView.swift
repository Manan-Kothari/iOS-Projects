//
//  NowPlayingView.swift
//  MusicShuffle
//

import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @State private var isShowingQueue = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ArtworkView(artwork: player.nowPlaying?.artwork, size: 300)
                    .shadow(radius: 12)

                VStack(spacing: 4) {
                    Text(player.nowPlaying?.title ?? "Not Playing")
                        .font(.title2.bold())
                    Text(player.nowPlaying?.artist ?? " ")
                        .foregroundStyle(.secondary)
                    Text(player.nowPlaying?.albumTitle ?? " ")
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .multilineTextAlignment(.center)

                if let duration = player.nowPlaying?.playbackDuration, duration > 0 {
                    ProgressSection(duration: duration)
                }

                controls

                VolumeSlider()
                    .frame(height: 44)
            }
            .padding()
            .navigationTitle(queueDescription)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingQueue) {
                QueueView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Queue", systemImage: "list.bullet") { isShowingQueue = true }
                        .disabled(player.albumCount == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if player.isLoadingQueue {
                        ProgressView()
                    } else {
                        Button("Shuffle Library", systemImage: "shuffle") {
                            player.shuffleLibrary()
                        }
                    }
                }
            }
        }
    }

    private var queueDescription: String {
        guard let title = player.queueTitle else { return "MusicShuffle" }
        guard let number = player.albumNumber else { return title }
        return "\(title) · Album \(number) of \(player.albumCount)"
    }

    private var controls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 44) {
                Button("Previous Song", systemImage: "backward.fill", action: player.previousSong)
                Button(player.isPlaying ? "Pause" : "Play",
                       systemImage: player.isPlaying ? "pause.fill" : "play.fill",
                       action: player.playPause)
                    .font(.system(size: 48))
                    .contentTransition(.symbolEffect(.replace))
                Button("Next Song", systemImage: "forward.fill", action: player.nextSong)
            }
            .font(.largeTitle)
            .labelStyle(.iconOnly)

            HStack {
                Button("Previous Album", systemImage: "chevron.backward.2", action: player.previousAlbum)
                Spacer()
                Button("Next Album", systemImage: "chevron.forward.2", action: player.nextAlbum)
            }
            .buttonStyle(.bordered)
            .disabled(player.albumNumber == nil)
        }
    }
}

/// The time slider. It reads the playback position twice a second.
private struct ProgressSection: View {
    @Environment(PlayerModel.self) private var player
    let duration: TimeInterval
    @State private var scrubTime: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let time = scrubTime ?? player.currentTime
            VStack(spacing: 4) {
                Slider(value: Binding(get: { time }, set: { scrubTime = $0 }),
                       in: 0...duration) { editing in
                    if !editing, let scrubTime {
                        player.seek(to: scrubTime)
                        self.scrubTime = nil
                    }
                }
                HStack {
                    Text(Duration.seconds(time), format: .time(pattern: .minuteSecond))
                    Spacer()
                    Text(Duration.seconds(duration), format: .time(pattern: .minuteSecond))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// The system volume slider and audio output button.
private struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        MPVolumeView(frame: .zero)
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
