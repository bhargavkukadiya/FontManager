// swift-tools-version: 6.0
// Used by Swift 6+ toolchains (Xcode 16+). Builds in the Swift 6 language mode so strict
// concurrency checking is enforced. Older toolchains use Package.swift (Swift 5 mode).

import PackageDescription

let package = Package(
    name: "FontManager",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "FontManager",
            targets: ["FontManager"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FontManager",
            dependencies: [],
            path: "Sources/FontManager"
        ),
        .testTarget(
            name: "FontManagerTests",
            dependencies: ["FontManager"],
            path: "Tests/FontManagerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
