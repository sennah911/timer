// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "timer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "timer", targets: ["timer"])
    ],
    dependencies: [
        .package(url: "https://github.com/rensbreur/SwiftTUI", revision: "537133031bc2b2731048d00748c69700e1b48185")
    ],
    targets: [
        .executableTarget(
            name: "timer",
            dependencies: [
                .product(name: "SwiftTUI", package: "SwiftTUI")
            ]),
        .testTarget(
            name: "timerTests",
            dependencies: ["timer"])
    ]
)
