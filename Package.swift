// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IPaVisionKit",
    // visionOS is the product platform. macOS is declared so the Core tests run
    // on the host without a simulator, and iOS so an app can link the Core
    // (e.g. to persist corrections) on every platform it builds for.
    // `IPaVisionKit` compiles to an empty module everywhere except visionOS.
    platforms: [.visionOS(.v26), .macOS(.v14), .iOS(.v17)],
    products: [
        /// Foundation + simd: correction model, metadata classification,
        /// mesh / orientation math and the scrub mapping. Host-testable.
        .library(name: "IPaVisionKitCore", targets: ["IPaVisionKitCore"]),
        /// visionOS RealityKit renderer, immersive view and scrub gesture.
        .library(name: "IPaVisionKit", targets: ["IPaVisionKit"]),
    ],
    targets: [
        .target(name: "IPaVisionKitCore"),
        .target(name: "IPaVisionKit", dependencies: ["IPaVisionKitCore"]),
        .testTarget(name: "IPaVisionKitCoreTests", dependencies: ["IPaVisionKitCore"]),
        .testTarget(name: "IPaVisionKitTests", dependencies: ["IPaVisionKit", "IPaVisionKitCore"]),
    ],
    swiftLanguageModes: [.v6]
)
