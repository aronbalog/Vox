// swift-tools-version: 6.0

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
        .library(name: "Vox", targets: ["Vox"]),
        .library(name: "VoxAlamofire", targets: ["VoxAlamofire"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0")
    ],
    targets: [
        .target(
            name: "Vox",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "VoxAlamofire",
            dependencies: ["Vox", "Alamofire"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "VoxTests",
            dependencies: ["Vox"],
            resources: [.process("Fixtures")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "VoxAlamofireTests",
            dependencies: ["Vox", "VoxAlamofire", "Alamofire"],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
