// swift-tools-version: 6.1

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny")
]

let package = Package(
    name: "Vox",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "Vox", targets: ["Vox"])
    ],
    targets: [
        .target(
            name: "Vox",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "VoxTests",
            dependencies: ["Vox"],
            resources: [.process("Fixtures")],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
