// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IPaVRKit",
    // iOS: the Cardboard / SceneKit player (`IPaVRKit`), unchanged.
    // visionOS: the RealityKit immersive renderer (`IPaVisionKit`).
    // `IPaVisionKitCore` (Foundation + simd) builds on both, so an iOS app can
    // persist corrections too. `IPaVisionKit` compiles to an empty module
    // everywhere except visionOS. There is no macOS slice: validate with
    // xcodebuild on simulators (see docs/visionOS/VALIDATION.md).
    platforms: [
        .iOS(.v15),
        .visionOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        /// iOS Cardboard / SceneKit VR player.
        .library(
            name: "IPaVRKit",
            targets: ["IPaVRKit"]),
        /// Foundation + simd: correction model, metadata classification,
        /// mesh / orientation math and the scrub mapping.
        .library(
            name: "IPaVisionKitCore",
            targets: ["IPaVisionKitCore"]),
        /// visionOS RealityKit renderer, immersive view and scrub gesture.
        .library(
            name: "IPaVisionKit",
            targets: ["IPaVisionKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/ipapamagic/IPaAVPlayer.git", from: "4.0.0"),
        .package(url: "https://github.com/ipapamagic/IPaImageTool.git", from: "2.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.

        // MARK: iOS (Swift 5 language mode)
        .target(
            name: "IPaVRKit",
            dependencies: [
                .product(name: "IPaAVPlayer", package: "IPaAVPlayer"),
                .product(name: "IPaImageTool", package: "IPaImageTool"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "IPaVRKitTests",
            dependencies: [
                "IPaVRKit",
                .product(name: "IPaAVPlayer", package: "IPaAVPlayer"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]),

        // MARK: visionOS (Swift 6 language mode)
        .target(
            name: "IPaVisionKitCore",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "IPaVisionKit",
            dependencies: ["IPaVisionKitCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "IPaVisionKitCoreTests",
            dependencies: ["IPaVisionKitCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "IPaVisionKitTests",
            dependencies: ["IPaVisionKit", "IPaVisionKitCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
