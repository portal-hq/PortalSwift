// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "PortalSwift",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "PortalSwift",
      targets: ["PortalSwift", "Mpc"]
    ),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(
      url: "https://github.com/google/GoogleSignIn-iOS.git",
      from: "7.1.0"
    ),
    .package(
      url: "https://github.com/daltoniam/Starscream.git",
      from: "4.0.7"
    ),
    .package(
      url: "https://github.com/Flight-School/AnyCodable.git",
      from: "0.6.7"
    ),
    .package(url: "https://github.com/p2p-org/solana-swift", from: "5.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "PortalSwift",
      dependencies: [
        "Mpc",
        .product(name: "AnyCodable", package: "AnyCodable"),
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
        .product(name: "Starscream", package: "Starscream"),
        .product(name: "SolanaSwift", package: "solana-swift"),
      ]
    ),
    .binaryTarget(
      name: "Mpc",
      path: "Sources/Frameworks/mpc.xcframework"
    ),
    .testTarget(
      name: "PortalSwiftTests",
      dependencies: ["Mpc", "PortalSwift"]
    ),
  ]
)
