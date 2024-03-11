// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Siren",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Siren",
            targets: [
                "Siren"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/scinfu/SwiftSoup.git",
            from: "2.6.1"
        )
    ],
    targets: [
        .target(
            name: "Siren",
            dependencies: [
                "SwiftSoup"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SirenTests",
            dependencies: [
                "Siren"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
