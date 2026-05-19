// swift-tools-version: 5.9

import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .testTarget(
        name: "FractalTests",
        dependencies: ["FractalCore"],
        path: "Tests/FractalTests"
    )
]

#if os(macOS)
products.append(.executable(name: "Fractal", targets: ["Fractal"]))
targets.insert(
    .target(
        name: "FractalCore",
        path: "Sources/Fractal"
    ),
    at: 0
)
targets.insert(
    .executableTarget(
        name: "Fractal",
        dependencies: ["FractalCore"],
        path: "Sources/FractalApp"
    ),
    at: 1
)
#else
targets.insert(
    .target(
        name: "FractalCore",
        path: "Sources/Fractal",
        exclude: [
            "AppDelegate.swift",
            "Components",
            "Views"
        ]
    ),
    at: 0
)
#endif

let package = Package(
    name: "Fractal",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
