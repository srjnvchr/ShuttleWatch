// swift-tools-version: 6.4

import PackageDescription

// Pure scoring logic shared by the iPhone and Watch apps.
// No UI, media, or connectivity imports. Must build and test with `swift test` alone.
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
    ],
    targets: [
        .target(
            name: "ScoringKit"
        ),
        .testTarget(
            name: "ScoringKitTests",
            dependencies: ["ScoringKit"]
        ),
    ]
)
