//
//  MusicShuffleApp.swift
//  MusicShuffle
//
//  Created by MMan on 8/5/16.
//  Copyright © 2016 MananKothari. All rights reserved.
//

import MediaPlayer
import MusicShuffleCore
import SwiftData
import SwiftUI

@main
struct MusicShuffleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = PlayerModel()
    @State private var recorder: StatsRecorder
    @State private var libraryAccess = MPMediaLibrary.authorizationStatus()
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    init() {
        let container: ModelContainer
        do {
            container = try PlayHistoryStore.makeContainer()
        } catch {
            fatalError("Could not open the play history: \(error)")
        }
        _recorder = State(initialValue: StatsRecorder(container: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(libraryAccess: libraryAccess)
                .environment(player)
                .environment(recorder)
                // Also applies to sheets, such as the queue.
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    libraryAccess = await MPMediaLibrary.requestAuthorization()
                    guard libraryAccess == .authorized else { return }
                    player.onSongChanged = { [recorder] song in
                        let id = song.persistentID
                        Task { await recorder.checkSong(id: id) }
                    }
                    player.prepareLibraryShuffle()
                    await recorder.checkLibrary()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await recorder.checkLibrary() }
            case .background:
                recorder.scheduleBackgroundRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(StatsRecorder.refreshTaskIdentifier)) {
            await recorder.checkLibrary()
            await recorder.scheduleBackgroundRefresh()
        }
    }
}
