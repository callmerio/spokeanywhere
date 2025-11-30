Project Path: spoke

Source Tree:

```txt
spoke
└── Package.swift

```

`spoke/Package.swift`:

```swift
   1 | // swift-tools-version: 5.9
   2 | import PackageDescription
   3 | 
   4 | let package = Package(
   5 |     name: "SpokenAnyWhere",
   6 |     platforms: [
   7 |         .macOS(.v14)
   8 |     ],
   9 |     products: [
  10 |         .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
  11 |     ],
  12 |     dependencies: [],
  13 |     targets: [
  14 |         .executableTarget(
  15 |             name: "SpokenAnyWhere",
  16 |             dependencies: [],
  17 |             path: ".",
  18 |             exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
  19 |             sources: ["App", "Core", "Services", "UI"]
  20 |         )
  21 |     ]
  22 | )

```