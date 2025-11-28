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
            exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
            sources: ["App", "Core", "Services", "UI"]
        )
    ]
)
