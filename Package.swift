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
        .package(url: "https://github.com/rensbreur/SwiftTUI", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "timer",
            dependencies: [
                .product(name: "SwiftTUI", package: "SwiftTUI")
            ])
    ]
)
