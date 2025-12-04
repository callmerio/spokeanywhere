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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpokenAnyWhere",
            dependencies: [],
            path: ".",
            exclude: [
                "Package.swift",
                "Resources/LocalModels",
                "Tests",
                "SpokenAnyWhere.app",  // 旧构建产物
                "dev.sh",              // 开发脚本
                "Bundler.toml"         // Swift Bundler 配置
            ],
            sources: ["App", "Core", "Services", "UI"]
        )
    ]
)
