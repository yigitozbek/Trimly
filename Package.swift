// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Trimly",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TrimlyCore", targets: ["TrimlyCore"]),
        .executable(name: "trimly", targets: ["trimly"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "TrimlyCore",
            path: "Sources/TrimlyCore"
        ),
        .executableTarget(
            name: "trimly",
            dependencies: [
                "TrimlyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/trimly"
        ),
        .testTarget(
            name: "TrimlyCoreTests",
            dependencies: ["TrimlyCore"],
            path: "Tests/TrimlyCoreTests"
        )
    ]
)
