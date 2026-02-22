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
                ".deprecated",         // 已弃用的私有 API 代码
                "cookies.txt",         // 本地调试文件（避免资源告警）
                // P3-B2: 仓库噪声路径（非源码目录/文件）
                "docs",
                "verify",
                "tasks",
                "archive",
                "spoke",               // 嵌套子目录（非源码）
                "build.log",
                "test.log",
                "progress.txt",
                "prd.json",
                "CLAUDE.md",
                "scripts",             // 性能测试脚本（非源码）
                "perf"                 // 性能基线数据（非源码）
            ],
            sources: ["App", "Core", "Services", "UI"]
        ),
        .testTarget(
            name: "SpokenAnyWhereTests",
            dependencies: ["SpokenAnyWhere"],
            path: "Tests",
            exclude: [
                "run-tests.sh",
                "test_edge_tts.swift",
                "TextExtractionTests.swift",  // 独立脚本，有 @main
                "EdgeTTSTests.swift",         // 独立脚本，有 @main
                "AttachmentTests.swift",      // 独立脚本，有 @main
                // P3-B2: 测试辅助文件（非测试源码）
                "run-concurrency-check.sh",
                "TEST_ISOLATION.md"
            ]
        )
    ]
)
