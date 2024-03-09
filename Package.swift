// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "PortalSwift",
  platforms: [
    .iOS(.v13),
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
      from: "6.2.4"
    ),
    .package(
      url: "https://github.com/daltoniam/Starscream.git",
      from: "4.0.6"
    ),
    .package(url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.8.7"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "PortalSwift",
      dependencies: [
        "Mpc",
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
        .product(name: "Starscream", package: "Starscream"),
        .product(name: "Web3", package: "Web3.swift"),
        .product(name: "Web3PromiseKit", package: "Web3.swift"),
        .product(name: "Web3ContractABI", package: "Web3.swift"),
      ]
    ),
    .binaryTarget(
      name: "Mpc",
      path: "Sources/Frameworks/Mpc.xcframework"
    ),
  ]
)
