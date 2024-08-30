// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Mastodon",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Mastodon",
            targets: ["Mastodon"])
    ],
    dependencies: [
        .package(path: "AppMetadata"),
        .package(path: "AppUrls"),
        .package(path: "Macros"),
        .package(path: "Siren"),
        .package(
            url: "https://github.com/scinfu/SwiftSoup.git",
            from: "2.6.1"
        )
    ],
    targets: [
        .target(
            name: "Mastodon",
            dependencies: ["AppMetadata", "AppUrls", "Macros", "Siren", "SwiftSoup"]),
        .testTarget(
            name: "MastodonTests",
            dependencies: ["Mastodon"])
    ]
)
