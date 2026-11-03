// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "vhash",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "vhash", targets: ["vhash"]),
        .library(name: "VHashCore", targets: ["VHashCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/fdenis75/VideoHash.git", from: "0.4.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "VHashCore",
            dependencies: [
                .product(name: "VideoHash", package: "VideoHash"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .executableTarget(
            name: "vhash",
            dependencies: ["VHashCore"]
        ),
        .testTarget(
            name: "VHashCoreTests",
            dependencies: ["VHashCore"]
        )
    ]
)
