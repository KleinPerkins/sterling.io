// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SterlingFeasibility",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "SterlingCore", targets: ["SterlingCore"]),
    .executable(name: "SterlingPrototype", targets: ["SterlingPrototype"]),
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
  ],
  targets: [
    .target(name: "SterlingCore"),
    .target(name: "SterlingUpdateSupport"),
    .executableTarget(
      name: "SterlingPrototype",
      dependencies: ["SterlingCore", "SterlingUpdateSupport", .product(name: "Sparkle", package: "Sparkle")],
      linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
    ),
    .testTarget(name: "SterlingUpdateSupportTests", dependencies: ["SterlingUpdateSupport"]),
    .testTarget(name: "SterlingCoreTests", dependencies: ["SterlingCore"]),
  ]
)
