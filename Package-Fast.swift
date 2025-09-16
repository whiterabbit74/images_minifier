// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PicsMinifier",
    defaultLocalization: "ru",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "PicsMinifierApp", targets: ["PicsMinifierApp"]),
        .library(name: "PicsMinifierCore", targets: ["PicsMinifierCore"])
    ],
    targets: [
        .target(
            name: "PicsMinifierCore",
            dependencies: [],
            path: "Sources/PicsMinifierCore",
            exclude: ["WebPEncoder.swift", "TestImages", "TestResults"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "PicsMinifierApp",
            dependencies: ["PicsMinifierCore"],
            path: "Sources/PicsMinifierApp"
        )
    ]
)