//
//  Runs on the visionOS simulator (xcodebuild test, xrsimulator). Proves the
//  RealityKit wiring compiles and assembles; it cannot prove what a headset
//  draws per eye.
//

#if os(visionOS)
import AVFoundation
import RealityKit
import XCTest
@testable import IPaVisionKit
import IPaVisionKitCore

@MainActor
final class IPaVisionKitTests: XCTestCase {
    private let player = AVPlayer()

    func testAutomaticTaggedImmersiveUsesVideoPlayerComponentFull() throws {
        let plan = IPaVisionRenderPlan.make(metadata: .init(projection: .equirectangular), correction: .automatic)
        let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: .automatic,
                                                           frameAspectRatio: nil)
        let component = try XCTUnwrap(entity.components[VideoPlayerComponent.self])
        XCTAssertTrue(component.avPlayer === player)
        XCTAssertEqual(component.desiredImmersiveViewingMode, .full)
        XCTAssertNil(entity.components[ModelComponent.self])
    }

    /// Regression: automatic Apple Immersive / parametric media must be
    /// presented `.full`, never in a portal.
    func testAutomaticAppleAndParametricImmersiveUseFull() throws {
        for projection: IPaVisionSourceMetadata.Projection in [.appleImmersive, .parametricImmersive, .otherNonRectilinear] {
            let plan = IPaVisionRenderPlan.make(metadata: .init(projection: projection), correction: .automatic)
            XCTAssertEqual(plan.projection, .systemImmersive)
            let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: .automatic,
                                                               frameAspectRatio: nil)
            let component = try XCTUnwrap(entity.components[VideoPlayerComponent.self], "\(projection)")
            XCTAssertEqual(component.desiredImmersiveViewingMode, .full, "\(projection) went to a portal")
            XCTAssertTrue(component.avPlayer === player)
            XCTAssertEqual(entity.position, .zero)                 // not placed as a theatre screen
            XCTAssertEqual(entity.scale, SIMD3<Float>(repeating: 1))
            XCTAssertNil(entity.components[ModelComponent.self])
        }
    }

    func testAutomaticEquirectangularUsesFull() throws {
        for projection: IPaVisionSourceMetadata.Projection in [.equirectangular, .halfEquirectangular] {
            let plan = IPaVisionRenderPlan.make(metadata: .init(projection: projection), correction: .automatic)
            let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: .automatic,
                                                               frameAspectRatio: nil)
            XCTAssertEqual(entity.components[VideoPlayerComponent.self]?.desiredImmersiveViewingMode, .full,
                           "\(projection)")
        }
    }

    /// The renderer only draws the player: building any entity leaves the
    /// transport (rate, item, position) untouched.
    func testRenderingNeverDrivesTransport() throws {
        let source = AVPlayer()
        let metas: [IPaVisionSourceMetadata] = [.init(projection: .rectilinear), .init(projection: .equirectangular),
                                                .init(projection: .appleImmersive), .init(projection: .parametricImmersive)]
        for meta in metas {
            for correction in [IPaVisionCorrection.automatic, IPaVisionCorrection(projection: .equirectangular180)] {
                let plan = IPaVisionRenderPlan.make(metadata: meta, correction: correction)
                _ = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: source, correction: correction,
                                                          frameAspectRatio: 16.0 / 9.0)
            }
        }
        XCTAssertEqual(source.rate, 0)
        XCTAssertNil(source.currentItem)
        XCTAssertEqual(source.timeControlStatus, .paused)
    }

    func testAutomaticFlatUsesPortalScreen() throws {
        let plan = IPaVisionRenderPlan.make(metadata: .init(projection: .rectilinear), correction: .automatic)
        let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: .automatic,
                                                           frameAspectRatio: nil)
        XCTAssertEqual(entity.components[VideoPlayerComponent.self]?.desiredImmersiveViewingMode, .portal)
        XCTAssertLessThan(entity.position.z, 0)
    }

    func testManualCorrectionUsesMeshWithVideoMaterial() throws {
        let correction = IPaVisionCorrection(projection: .equirectangular180, stereoLayout: .sideBySide, yaw: 30)
        let plan = IPaVisionRenderPlan.make(metadata: .init(projection: .rectilinear), correction: correction)
        XCTAssertEqual(plan.backend, .customMono)
        let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: correction,
                                                           frameAspectRatio: 32.0 / 9.0)
        let model = try XCTUnwrap(entity.components[ModelComponent.self])
        XCTAssertTrue(model.materials.first is VideoMaterial)
        XCTAssertTrue((model.materials.first as? VideoMaterial)?.avPlayer === player)
        XCTAssertNil(entity.components[VideoPlayerComponent.self])
        XCTAssertEqual(entity.orientation, IPaVisionGeometry.orientation(for: correction))
        XCTAssertGreaterThan(model.mesh.bounds.extents.x, 30)   // 180° hemisphere of radius 20
    }

    func testInputShellIsIndirectOnlyCollisionWithoutModel() async throws {
        let shell = try await IPaVisionRenderer.makeInputShell()
        XCTAssertEqual(shell.components[InputTargetComponent.self]?.allowedInputTypes, .indirect)
        XCTAssertNotNil(shell.components[CollisionComponent.self])
        XCTAssertNotNil(shell.components[IPaVisionInputShellComponent.self])
        XCTAssertNil(shell.components[ModelComponent.self])   // never drawn
    }

    func testCustomStereoIsAnExplicitStub() {
        XCTAssertFalse(IPaVisionCustomStereoBackend.status.isAvailable)
        let plan = IPaVisionRenderPlan.make(metadata: .init(projection: .rectilinear),
                                            correction: IPaVisionCorrection(stereoLayout: .overUnder))
        XCTAssertNil(IPaVisionCustomStereoBackend.makeEntity(plan: plan, player: player))
    }

    func testSceneRebuildsOnlyForGeometryChanges() throws {
        let scene = IPaVisionImmersiveScene()
        let meta = IPaVisionSourceMetadata(projection: .rectilinear)
        scene.apply(player: player, metadata: meta, correction: IPaVisionCorrection(projection: .equirectangular360))
        let first = try XCTUnwrap(scene.root.children.first)
        scene.apply(player: player, metadata: meta, correction: IPaVisionCorrection(projection: .equirectangular360, yaw: 45))
        XCTAssertTrue(scene.root.children.first === first)       // re-oriented in place
        XCTAssertEqual(first.orientation, IPaVisionGeometry.orientation(for: IPaVisionCorrection(yaw: 45)))
        scene.apply(player: player, metadata: meta, correction: .automatic)
        XCTAssertFalse(scene.root.children.first === first)      // backend changed
        XCTAssertEqual(scene.plan?.backend, .system)
        XCTAssertEqual(scene.root.children.count, 1)
    }

    func testTimeFormat() {
        XCTAssertEqual(IPaVisionTimeFormat.string(75), "01:15")
        XCTAssertEqual(IPaVisionTimeFormat.string(3725), "1:02:05")
        XCTAssertEqual(IPaVisionTimeFormat.string(.nan), "--:--")
    }
}
#endif
