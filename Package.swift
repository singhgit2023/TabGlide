// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowHop",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WindowHop", targets: ["WindowHop"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [.executableTarget(
        name: "WindowHop",
        dependencies: [.product(name: "Sparkle", package: "Sparkle")],
        linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
    )]
)
