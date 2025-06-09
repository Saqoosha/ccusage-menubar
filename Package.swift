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
            path: "tests",
            exclude: [
                "check_costUSD_field.py",
                "check_litellm_pricing.py", 
                "compare_cost_not_tokens.py",
                "compare_json.py",
                "find_correct_opus_price.py",
                "find_exact_cache_rate.py",
                "reverse_engineer_pricing.py",
                "test_cost.py",
                "test_all.sh"
            ]
        ),
    ]
)