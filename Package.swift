// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TopBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TopBar", targets: ["TopBar"])],
    targets: [
        .executableTarget(name: "TopBar")
    ]
)
