// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "MedidorClaude",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "MedidorClaude", path: "Sources/MedidorClaude")]
)
