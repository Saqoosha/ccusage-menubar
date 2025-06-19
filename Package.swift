// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageMenuBar",
    platforms: [
        .macOS(.v13) // MenuBarExtra requires macOS 13.0+
    ],
    products: [
        .executable(
            name: "ClaudeUsageMenuBar",
            targets: ["ClaudeUsageMenuBar"]
        ),
    ],
    dependencies: [
        // No external dependencies - keeping it lightweight
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageMenuBar",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "ClaudeUsageMenuBarTests",
            dependencies: ["ClaudeUsageMenuBar"],
            path: "Tests/ClaudeUsageMenuBarTests"
        ),
    ]
)