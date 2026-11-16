// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MusicShuffleCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MusicShuffleCore", targets: ["MusicShuffleCore"]),
    ],
    targets: [
        .target(name: "MusicShuffleCore"),
        .testTarget(name: "MusicShuffleCoreTests", dependencies: ["MusicShuffleCore"]),
    ]
)
