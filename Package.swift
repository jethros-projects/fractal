// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Fractal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Fractal", targets: ["Fractal"])
    ],
    targets: [
        .executableTarget(
            name: "Fractal",
            path: "Sources/Fractal"
        )
    ]
)
