// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "timer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "timer", targets: ["timer"]),
        .library(name: "TimerCore", targets: ["TimerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/rensbreur/SwiftTUI", revision: "537133031bc2b2731048d00748c69700e1b48185")
    ],
    targets: [
        .target(
            name: "TimerCore",
            dependencies: [],
            path: "Sources/timer",
            exclude: [
                "CLI",
                "Dashboard",
                "main.swift"
            ]
        ),
        .executableTarget(
            name: "timer",
            dependencies: [
                "TimerCore",
                .product(name: "SwiftTUI", package: "SwiftTUI")
            ],
            path: "Sources/timer",
            sources: [
                "CLI",
                "Dashboard",
                "main.swift"
            ]),
        .testTarget(
            name: "timerTests",
            dependencies: ["TimerCore"])
    ]
)
