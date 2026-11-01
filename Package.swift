// swift-tools-version: 6.0

import PackageDescription

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
        .target(name: "Vox"),
        .testTarget(
            name: "VoxTests",
            dependencies: ["Vox"],
            resources: [.process("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
