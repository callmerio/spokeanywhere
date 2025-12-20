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
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SpokenAnyWhere",
            dependencies: [
                .product(name: "IdentifiedCollections", package: "swift-identified-collections")
            ],
            path: ".",
            exclude: [
                "Package.swift",
                "Resources/LocalModels",
                "Tests",
                "SpokenAnyWhere.app",  // 旧构建产物
                "dev.sh",              // 开发脚本
                "Bundler.toml",        // Swift Bundler 配置
                ".deprecated"          // 已弃用的私有 API 代码
            ],
            sources: ["App", "Core", "Services", "UI"]
        )
    ]
)
