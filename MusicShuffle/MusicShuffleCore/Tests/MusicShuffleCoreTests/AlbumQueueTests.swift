import Testing
@testable import MusicShuffleCore

struct AlbumQueueTests {
    // Albums of uneven size, the case that broke the old track number math.
    let albums: [[String]] = (0..<50).map { album in
        (1...(1 + album % 7)).map { "A\(album)-T\($0)" }
    }

    @Test(arguments: 0..<20)
    func keepsEveryAlbumWholeAndInOrder(seed: UInt64) {
        var generator = SeededGenerator(state: seed)
        let queue = AlbumQueue(albums: albums + [[]], using: &generator)

        #expect(queue.songs.sorted() == albums.flatMap { $0 }.sorted())
        #expect(queue.albumCount == albums.count)
        for (index, start) in queue.albumStartIndices.enumerated() {
            let end = index + 1 < queue.albumCount ? queue.albumStartIndices[index + 1] : queue.songs.count
            #expect(albums.contains(Array(queue.songs[start..<end])))
        }
    }

    @Test func shufflesTheAlbumOrder() {
        var orders = Set<[String]>()
        for seed in 0..<100 as Range<UInt64> {
            var generator = SeededGenerator(state: seed)
            let queue = AlbumQueue(albums: albums, using: &generator)
            orders.insert(queue.albumStartIndices.map { queue.songs[$0] })
        }
        #expect(orders.count > 95)
    }

    @Test func nextAndPreviousAlbumFromEverySong() {
        var generator = SeededGenerator(state: 7)
        let queue = AlbumQueue(albums: albums, using: &generator)
        let starts = queue.albumStartIndices

        for songIndex in queue.songs.indices {
            let album = starts.lastIndex { $0 <= songIndex }!
            #expect(queue.albumIndex(containingSongAt: songIndex) == album)
            #expect(queue.startOfNextAlbum(afterSongAt: songIndex) == starts[(album + 1) % starts.count])
            #expect(queue.startOfPreviousAlbum(beforeSongAt: songIndex) == starts[(album - 1 + starts.count) % starts.count])
        }
    }

    @Test func songIndicesOfEachAlbum() throws {
        var generator = SeededGenerator(state: 3)
        let queue = AlbumQueue(albums: albums, using: &generator)

        var covered: [Int] = []
        for album in 0..<queue.albumCount {
            let range = try #require(queue.songIndices(ofAlbumAt: album))
            #expect(range.lowerBound == queue.albumStartIndices[album])
            #expect(range.allSatisfy { queue.albumIndex(containingSongAt: $0) == album })
            covered += range
        }
        #expect(covered == Array(queue.songs.indices))
        #expect(queue.songIndices(ofAlbumAt: queue.albumCount) == nil)
        #expect(queue.songIndices(ofAlbumAt: -1) == nil)
    }

    @Test func wrapsAroundAtTheEnds() {
        let queue = AlbumQueue(albums: [["a1", "a2"], ["b1"], ["c1", "c2", "c3"]], firstAlbum: 0)
        let lastSong = queue.songs.count - 1
        #expect(queue.startOfNextAlbum(afterSongAt: lastSong) == 0)
        #expect(queue.startOfPreviousAlbum(beforeSongAt: 0) == queue.albumStartIndices.last)
    }

    @Test(arguments: 0..<10)
    func playsTheChosenAlbumFirst(seed: UInt64) {
        var generator = SeededGenerator(state: seed)
        let queue = AlbumQueue(albums: albums, firstAlbum: 12, using: &generator)
        #expect(Array(queue.songs.prefix(albums[12].count)) == albums[12])
        #expect(queue.songs.count == albums.flatMap { $0 }.count)
    }

    @Test func ignoresAFirstAlbumOutOfRange() {
        let queue = AlbumQueue(albums: [["a"], ["b"]], firstAlbum: 5)
        #expect(queue.songs.sorted() == ["a", "b"])
    }

    @Test func emptyAndInvalidIndices() {
        let empty = AlbumQueue<String>(albums: [])
        #expect(empty.isEmpty)
        #expect(empty.startOfNextAlbum(afterSongAt: 0) == nil)
        #expect(empty.startOfPreviousAlbum(beforeSongAt: 0) == nil)

        let single = AlbumQueue(albums: [["x", "y"]])
        #expect(single.startOfNextAlbum(afterSongAt: 1) == 0)
        #expect(single.startOfPreviousAlbum(beforeSongAt: 1) == 0)
        #expect(single.albumIndex(containingSongAt: 2) == nil)
        #expect(single.albumIndex(containingSongAt: -1) == nil)
    }

    @Test func groupsSongsByAlbumInFirstAppearanceOrder() {
        let playlist = [("s1", "B"), ("s2", "A"), ("s3", "B"), ("s4", "C"), ("s5", "A")]
        let grouped = AlbumQueue<(String, String)>.groupedByAlbum(playlist) { $0.1 }
        #expect(grouped.map { $0.map(\.0) } == [["s1", "s3"], ["s2", "s5"], ["s4"]])
    }
}
