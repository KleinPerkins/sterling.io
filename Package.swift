// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SterlingFeasibility",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "SterlingCore", targets: ["SterlingCore"]),
    .executable(name: "SterlingPrototype", targets: ["SterlingPrototype"]),
  ],
  targets: [
    .target(name: "SterlingCore"),
    .executableTarget(name: "SterlingPrototype", dependencies: ["SterlingCore"]),
    .testTarget(name: "SterlingCoreTests", dependencies: ["SterlingCore"]),
  ]
)
