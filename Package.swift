// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageMeter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClaudeUsageMeter", path: "Sources/ClaudeUsageMeter")
    ]
)
