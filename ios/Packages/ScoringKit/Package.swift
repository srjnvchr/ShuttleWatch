// swift-tools-version: 6.4

import PackageDescription

// ScoringKit: pure scoring logic shared by the iPhone and Watch apps.
// No UI, media, or connectivity imports. Must build and test with `swift test` alone.
//
// WatchLink: the messages the iPhone and Watch send each other (FR-07).
// Plain Codable types only. The apps do the WatchConnectivity work.
let package = Package(
    name: "ScoringKit",
    platforms: [
        .iOS("27.2"),
        .watchOS("27.2"),
    ],
    products: [
        .library(
            name: "ScoringKit",
            targets: ["ScoringKit"]
        ),
        .library(
            name: "WatchLink",
            targets: ["WatchLink"]
        ),
    ],
    targets: [
        .target(
            name: "ScoringKit"
        ),
        .target(
            name: "WatchLink",
            dependencies: ["ScoringKit"]
        ),
        .testTarget(
            name: "ScoringKitTests",
            dependencies: ["ScoringKit"]
        ),
        .testTarget(
            name: "WatchLinkTests",
            dependencies: ["WatchLink"]
        ),
    ]
)
