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
        .target(
            name: "FractalCore",
            path: "Sources/Fractal"
        ),
        .executableTarget(
            name: "Fractal",
            dependencies: ["FractalCore"],
            path: "Sources/FractalApp"
        ),
        .testTarget(
            name: "FractalTests",
            dependencies: ["FractalCore"],
            path: "Tests/FractalTests"
        )
    ]
)
