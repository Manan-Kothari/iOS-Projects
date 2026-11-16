import Foundation
@testable import MusicShuffleCore

/// A random generator with a fixed seed (SplitMix64), so test runs repeat.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A Gregorian calendar in UTC with weeks that start on Monday.
let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

/// A date from an ISO 8601 string in UTC, for example "2026-11-16T10:00:00Z".
func date(_ string: String) -> Date {
    try! Date(string, strategy: .iso8601)
}

func song(_ id: UInt64,
          title: String? = nil,
          artist: String = "Artist",
          album: String = "Album",
          playCount: Int,
          lastPlayed: Date? = nil,
          duration: TimeInterval = 180) -> LibrarySong {
    LibrarySong(id: id,
                title: title ?? "Song \(id)",
                artist: artist,
                albumArtist: artist,
                albumTitle: album,
                playCount: playCount,
                lastPlayedDate: lastPlayed,
                duration: duration)
}

func event(_ song: LibrarySong, at date: Date, count: Int = 1, kind: PlayEvent.Kind = .exact) -> PlayEvent {
    PlayEvent(song: song, date: date, count: count, kind: kind)
}
