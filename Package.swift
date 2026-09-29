// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ostrovok",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Ostrovok",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Ostrovok"
        )
    ]
)
