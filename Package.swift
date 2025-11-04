// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "timer",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "timer", targets: ["timer"])
    ],
    targets: [
        .executableTarget(
            name: "timer")
    ]
)
