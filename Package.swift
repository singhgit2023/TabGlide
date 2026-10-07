// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "WindowHop", platforms: [.macOS(.v13)], products: [.executable(name: "WindowHop", targets: ["WindowHop"])], targets: [.executableTarget(name: "WindowHop")])
