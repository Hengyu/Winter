// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Winter",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v6),
        .macCatalyst(.v13),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "Winter", targets: ["Winter"])
    ],
    targets: [
        .target(name: "Winter", dependencies: []),
        .testTarget(name: "WinterTests", dependencies: ["Winter"])
    ]
)
