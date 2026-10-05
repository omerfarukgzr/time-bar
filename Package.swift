// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TimeBar",
    platforms: [.macOS("14.0")],
    targets: [
        .executableTarget(name: "TimeBar", path: "Sources/TimeBar")
    ]
)
