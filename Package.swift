// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "FolderHub",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "FolderHub", targets: ["FolderHub"])
  ],
  targets: [
    .executableTarget(
      name: "FolderHub",
      path: "Sources/FolderHub"
    ),
    .testTarget(
      name: "FolderHubTests",
      dependencies: ["FolderHub"],
      path: "Tests/FolderHubTests"
    ),
  ],
  swiftLanguageModes: [.v5]
)
