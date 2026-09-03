// swift-tools-version: 6.0
import PackageDescription

// Core library for the standalone Songr player (Architecture v3).
// Platform-neutral on purpose: everything here must build and test on macOS
// with `swift test` (the repo boundary forbids booting an iOS Simulator),
// so no UIKit/CarPlay/AVFoundation imports live in this package.
let package = Package(
    name: "SongrKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SongrKit", targets: ["SongrKit"])
    ],
    targets: [
        .target(name: "SongrKit"),
        .testTarget(name: "SongrKitTests", dependencies: ["SongrKit"]),
    ]
)
