// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "DomainsResolution",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "DomainsResolution",
            targets: ["DomainsResolution"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.8.3")),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.4.1"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.6"),
    ],
    targets: [
        .target(
            name: "DomainsResolution",
            dependencies: [
                "CryptoSwift",
                "BigInt"
            ],
            resources: [
                .process("Resources/UNS/resolver-keys.json"),
                .process("Resources/UNS/unsProxyReader.json"),
                .process("Resources/UNS/unsRegistry.json"),
                .process("Resources/UNS/cnsRegistry.json"),
                .process("Resources/UNS/unsResolver.json"),
                .process("Resources/UNS/uns-config.json")
            ],
            swiftSettings: [.define("INSIDE_PM")]
        ),
        .testTarget(
            name: "DomainsResolutionTests",
            dependencies: ["DomainsResolution"],
            swiftSettings: [.define("INSIDE_PM")]
        )
    ]
)
