// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "AppUrls",
    products: [
        .library(
            name: "AppUrls",
            targets: ["AppUrls"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AppUrls",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AppUrlsTests",
            dependencies: ["AppUrls"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
