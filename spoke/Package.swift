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
                "Tests",
                "dev.sh",              // 开发脚本
                "Bundler.toml",        // Swift Bundler 配置
                ".deprecated",         // 已弃用的私有 API 代码
                "cookies.txt",         // 本地调试文件（避免资源告警）
                // P3-B2: 仓库噪声路径（非源码目录/文件）
                // 这里只保留当前 worktree 中真实存在的路径，避免 stale exclude 反向制造构建告警。
                "docs",
                "verify",
                "tasks",
                "archive",
                "progress.txt",
                "prd.json",
                "CLAUDE.md",
                "autoresearch",       // autoresearch 运行产物（非源码）
                "issues",             // issue 快照（非源码）
                "scripts",             // 性能测试脚本（非源码）
                "perf",                // 性能基线数据（非源码）
            ],
            sources: ["App", "Core", "Services", "UI"],
            resources: [
                .process("Resources/markdown-assets")
            ]
        ),
        .testTarget(
            name: "SpokenAnyWhereTests",
            dependencies: ["SpokenAnyWhere"],
            path: "Tests",
            exclude: [
                "UITests",
                "run-tests.sh",
                // P3-B2: 测试辅助文件（非测试源码）
                "run-concurrency-check.sh",
                "TEST_ISOLATION.md"
            ]
        ),
        .testTarget(
            name: "SpokenAnyWhereUITests",
            dependencies: ["SpokenAnyWhere"],
            path: "Tests/UITests"
        )
    ]
)
