//
//  StatsRecorder.swift
//  MusicShuffle
//

import BackgroundTasks
import MediaPlayer
import MusicShuffleCore
import Observation
import os
import SwiftData

/// Finds new plays in the music library and saves them in the play history.
///
/// The library keeps a play count for each song, which includes plays in the Music app.
/// The recorder checks all play counts when the app becomes active and in background refreshes.
/// It also checks one song shortly after that song stops playing in the app.
/// The library reads and the database work run off the main thread.
@Observable
final class StatsRecorder {
    static let refreshTaskIdentifier = "MananKothari.MusicShuffle.statsRefresh"

    /// Changes after each check that finds new plays, so that views reload.
    private(set) var revision = 0
    private(set) var isCheckingLibrary = false

    @ObservationIgnored private let storeTask: Task<PlayHistoryStore, Never>
    @ObservationIgnored private var libraryCheck: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "MananKothari.MusicShuffle", category: "Stats")

    init(container: ModelContainer) {
        // Make the store off the main thread, so that its model context does its work off the main thread.
        storeTask = Task.detached { PlayHistoryStore(modelContainer: container) }
    }

    var store: PlayHistoryStore {
        get async { await storeTask.value }
    }

    /// Checks the play counts of the whole library. A call during a check waits for that check.
    func checkLibrary() async {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { return }
        if let libraryCheck {
            return await libraryCheck.value
        }
        let check = Task {
            isCheckingLibrary = true
            let songs = await MediaLibrary.songs()
            await save(songs, isFullLibrary: true)
            isCheckingLibrary = false
        }
        libraryCheck = check
        await check.value
        libraryCheck = nil
    }

    /// Checks one song. The library can take a short time to update the play count after a song ends.
    func checkSong(id: MPMediaEntityPersistentID) async {
        try? await Task.sleep(for: .seconds(5))
        await save(await MediaLibrary.songs(withID: id), isFullLibrary: false)
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = .now.addingTimeInterval(4 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Could not schedule the stats refresh: \(error)")
        }
    }

    private func save(_ songs: [LibrarySong], isFullLibrary: Bool) async {
        do {
            let newPlays = try await store.reconcile(songs, isFullLibrary: isFullLibrary)
            if !newPlays.isEmpty {
                revision += 1
            }
        } catch {
            logger.error("Could not save play counts: \(error)")
        }
    }
}
