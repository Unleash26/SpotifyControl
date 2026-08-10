// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpotifyControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SpotifyControl",
            targets: ["SpotifyControl"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SpotifyControl",
            path: "Sources/SpotifyControl"
        ),
        .testTarget(
            name: "SpotifyControlTests",
            dependencies: ["SpotifyControl"],
            path: "Tests/SpotifyControlTests"
        )
    ]
)
