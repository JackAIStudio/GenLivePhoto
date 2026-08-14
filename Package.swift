// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GenLivePhoto",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GenLivePhoto", targets: ["GenLivePhoto"])
    ],
    targets: [
        .executableTarget(name: "GenLivePhoto"),
        .testTarget(
            name: "GenLivePhotoTests",
            dependencies: ["GenLivePhoto"]
        )
    ]
)
