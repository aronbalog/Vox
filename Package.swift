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
        .library(name: "Vox", targets: ["Vox"]),
        .library(name: "VoxAlamofire", targets: ["VoxAlamofire"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0")
    ],
    targets: [
        .target(name: "Vox"),
        .target(
            name: "VoxAlamofire",
            dependencies: ["Vox", "Alamofire"]
        ),
        .testTarget(
            name: "VoxTests",
            dependencies: ["Vox"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "VoxAlamofireTests",
            dependencies: ["Vox", "VoxAlamofire", "Alamofire"]
        )
    ],
    swiftLanguageModes: [.v5]
)
