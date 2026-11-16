# Music Player applicaton
This application shuffles your music on the system library by album. 

The app builds its own queue: the albums are in a random order, and the songs in each album stay in track order. It does not use the shuffle mode of the system music player.

Written in Swift and SwiftUI. Requires iOS 26 or later.

## Features

- Now Playing with previous and next song, and previous and next album.
- Artists: shuffle the albums of an artist, or pick an album to play first.
- Playlists: shuffle a playlist by album. The songs of each album stay in playlist order.
- Stats: plays, listening time, and top songs, artists and albums for a day, week, month, year, all time, or a custom range.

## How plays are counted

iOS gives apps no play history. It gives only a play count and a last played date for each song. These include plays in the Music app.

The app saves the play counts when it becomes active, in background refreshes, and a few seconds after a song stops in the app. An increase in a count is a new play:

- The most recent play gets the exact last played date.
- Other plays since the last check get the middle of the time between the two checks. The Stats screen shows how many plays have an estimated date.
- Plays from before the app first saw a song have no date. They count toward All Time only.

## Project layout

- `MusicShuffle.xcworkspace`: open this. Cmd+U builds the app and runs the tests.
- `MusicShuffle/`: the SwiftUI app.
- `MusicShuffleCore/`: a Swift package with the album queue, play counting, statistics and storage (SwiftData). It has no iOS-only code, so `swift test` in this folder runs the tests on a Mac.

To be added:

1. App icon artwork.
