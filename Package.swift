// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Cove",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Cove", path: "App")
    ]
)
