// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpokenAnyWhere",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
    ],
    dependencies: [
        // HotKey 库暂时不用，我们自己实现了 EventTap
        // .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        // WhisperKit 后续添加
        // .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "SpokenAnyWhere",
            dependencies: [],
            path: ".",
            exclude: ["Package.swift", "Resources/LocalModels"],
            sources: ["App", "Core", "Services", "UI"]
        )
    ]
)
