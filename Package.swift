// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
    ]
)
