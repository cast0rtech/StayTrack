// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StayTrackCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StayTrackCore",
            targets: ["StayTrackCore"]
        ),
    ],
    targets: [
        .target(
            name: "StayTrackCore",
            dependencies: []
        ),
        .testTarget(
            name: "StayTrackCoreTests",
            dependencies: ["StayTrackCore"]
        ),
    ]
)
