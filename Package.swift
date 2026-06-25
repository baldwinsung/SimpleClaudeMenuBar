// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimpleClaudeMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SimpleClaudeMenuBar",
            path: "Sources/SimpleClaudeMenuBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SimpleClaudeMenuBarTests",
            dependencies: ["SimpleClaudeMenuBar"],
            path: "Tests/SimpleClaudeMenuBarTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
