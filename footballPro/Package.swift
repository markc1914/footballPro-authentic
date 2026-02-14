// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "footballPro",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "footballPro",
            targets: ["footballPro"]
        )
    ],
    targets: [
        .executableTarget(
            name: "footballPro",
            path: "footballPro"
        ),
        .testTarget(
            name: "footballProTests",
            dependencies: ["footballPro"],
            path: "Tests"
        )
    ]
)
