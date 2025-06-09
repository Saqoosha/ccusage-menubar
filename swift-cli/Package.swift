// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeCostCLI",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCostCLI",
            dependencies: [],
            path: "Sources"
        ),
    ]
)