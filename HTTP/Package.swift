// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "HTTP",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "HTTP",
            targets: ["HTTP"]),
        .library(
            name: "Stubbing",
            targets: ["Stubbing"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HTTP",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "Stubbing",
            dependencies: ["HTTP"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HTTPTests",
            dependencies: ["HTTP"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
