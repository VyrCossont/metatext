// swift-tools-version: 5.10

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Macros",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Macros",
            targets: ["Macros"]
        ),
        .executable(
            name: "MacrosClient",
            targets: ["MacrosClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .macro(
            name: "MacroImplementations",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "Macros", dependencies: ["MacroImplementations"]),
        .executableTarget(name: "MacrosClient", dependencies: ["Macros"]),
        .testTarget(
            name: "MacroTests",
            dependencies: [
                "MacroImplementations",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
