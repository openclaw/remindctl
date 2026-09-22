// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "remindctl",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "RemindCore", targets: ["RemindCore"]),
    .executable(name: "remindctl", targets: ["remindctl"]),
  ],
  dependencies: [
    .package(url: "https://github.com/steipete/Commander.git", from: "0.3.0"),
  ],
  targets: [
    .target(
      name: "RemindCore",
      dependencies: [],
      linkerSettings: [
        .linkedFramework("CoreLocation"),
        .linkedFramework("EventKit"),
      ]
    ),
    .executableTarget(
      name: "remindctl",
      dependencies: [
        "RemindCore",
        .product(name: "Commander", package: "Commander"),
      ],
      exclude: [
        "Resources/Info.plist",
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/remindctl/Resources/Info.plist",
        ]),
      ]
    ),
    .testTarget(
      name: "RemindCoreTests",
      dependencies: [
        "RemindCore",
      ]
    ),
    .testTarget(
      name: "remindctlTests",
      dependencies: [
        "remindctl",
        "RemindCore",
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
