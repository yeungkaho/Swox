// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwoxLib",
    platforms: [
      .iOS(.v13),
      .macOS(.v10_14),
    ],
    products: [
        .library(name: "SwoxLib", targets: ["SwoxLib"]),
    ],
    targets: [
        .target(name: "SwoxLib", path: "SwoxLib")
    ],
    swiftLanguageVersions: [.v5]
)
