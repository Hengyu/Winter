// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Winter",
    platforms: [
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v6),
        .macCatalyst(.v13),
        .macOS(.v10_10)
    ],
    products: [
        .library(name: "Winter", targets: ["Winter"])
    ],
    targets: [
        .target(name: "Winter", dependencies: []),
        .testTarget(name: "WinterTests", dependencies: ["Winter"])
    ]
)
