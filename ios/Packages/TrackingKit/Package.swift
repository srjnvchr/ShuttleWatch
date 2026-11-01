// swift-tools-version: 6.4

import PackageDescription

// TrackingKit: finds players and the shuttle in video frames (FR-26, FR-27).
// Shared by the iPhone app (live) and the track-video tool on the Mac (recordings),
// so tracking fixes can be tested on the same footage again and again.
let package = Package(
    name: "TrackingKit",
    platforms: [
        .iOS("27.2"),
        .macOS("27.0"),
    ],
    products: [
        .library(
            name: "TrackingKit",
            targets: ["TrackingKit"]
        ),
        .executable(
            name: "track-video",
            targets: ["track-video"]
        ),
    ],
    targets: [
        .target(
            name: "TrackingKit"
        ),
        .executableTarget(
            name: "track-video",
            dependencies: ["TrackingKit"]
        ),
        .testTarget(
            name: "TrackingKitTests",
            dependencies: ["TrackingKit"]
        ),
    ]
)
