import XCTest
@testable import IPaVisionKitCore

final class IPaVisionRenderPlanTests: XCTestCase {
    typealias Meta = IPaVisionSourceMetadata
    typealias Value = IPaVisionSourceMetadata.CoreMediaValue

    // MARK: Classification

    func testClassifiesTags() {
        XCTAssertEqual(Meta.classify(projectionKinds: [], packingKinds: [], isMultiview: false, flaggedNonRectilinear: false),
                       Meta(projection: .rectilinear, packing: .mono))
        XCTAssertEqual(Meta.classify(projectionKinds: [Value.equirectangular], packingKinds: [Value.overUnder],
                                     isMultiview: false, flaggedNonRectilinear: true),
                       Meta(projection: .equirectangular, packing: .overUnder))
        XCTAssertEqual(Meta.classify(projectionKinds: [Value.halfEquirectangular], packingKinds: [Value.sideBySide],
                                     isMultiview: false, flaggedNonRectilinear: false),
                       Meta(projection: .halfEquirectangular, packing: .sideBySide))
        // MV-HEVC wins over a packing tag.
        XCTAssertEqual(Meta.classify(projectionKinds: [], packingKinds: [Value.sideBySide],
                                     isMultiview: true, flaggedNonRectilinear: false).packing, .multiview)
        // Known immersive kinds are named explicitly.
        XCTAssertEqual(Meta.classify(projectionKinds: [Value.parametricImmersive], packingKinds: [],
                                     isMultiview: false, flaggedNonRectilinear: false).projection, .parametricImmersive)
        XCTAssertEqual(Meta.classify(projectionKinds: [Value.appleImmersiveVideo], packingKinds: [],
                                     isMultiview: false, flaggedNonRectilinear: true).projection, .appleImmersive)
        // A kind this build doesn't know is still not flat.
        XCTAssertEqual(Meta.classify(projectionKinds: ["SomeFutureKind"], packingKinds: [],
                                     isMultiview: false, flaggedNonRectilinear: false).projection, .otherNonRectilinear)
        XCTAssertEqual(Meta.classify(projectionKinds: [], packingKinds: [], isMultiview: false,
                                     flaggedNonRectilinear: true).projection, .otherNonRectilinear)
    }

    func testTaggedFlag() {
        XCTAssertFalse(Meta.undetermined.isTaggedImmersiveOrStereo)
        XCTAssertFalse(Meta(projection: .rectilinear).isTaggedImmersiveOrStereo)
        XCTAssertTrue(Meta(projection: .rectilinear, packing: .multiview).isTaggedImmersiveOrStereo)
        XCTAssertTrue(Meta(projection: .equirectangular).isTaggedImmersiveOrStereo)
    }

    func testInvalidAspectIsDropped() {
        XCTAssertNil(Meta(projection: nil, frameAspectRatio: .nan).frameAspectRatio)
        XCTAssertNil(Meta(projection: nil, frameAspectRatio: 0).frameAspectRatio)
    }

    // MARK: Plan

    func testAutomaticCorrectionUsesSystemRenderer() {
        for meta in [Meta.undetermined, Meta(projection: .equirectangular, packing: .overUnder),
                     Meta(projection: .rectilinear, packing: .multiview)] {
            let plan = IPaVisionRenderPlan.make(metadata: meta, correction: .automatic)
            XCTAssertEqual(plan.backend, .system)
            XCTAssertEqual(plan.sourceRegion, .unit)
            XCTAssertFalse(plan.stereoShownAsMono)
        }
    }

    func testManualCorrectionUsesCustomMono() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear),
                                            correction: IPaVisionCorrection(projection: .equirectangular180))
        XCTAssertEqual(plan.backend, .customMono)
        XCTAssertEqual(plan.projection, .equirectangular180)
        XCTAssertEqual(plan.stereoLayout, .mono)
        XCTAssertEqual(plan.notes, [])
    }

    func testAutoFieldsFollowTheTags() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .equirectangular, packing: .overUnder),
                                            correction: IPaVisionCorrection(yaw: 10))
        XCTAssertEqual(plan.projection, .equirectangular360)
        XCTAssertEqual(plan.stereoLayout, .overUnder)
        XCTAssertTrue(plan.stereoShownAsMono)
        XCTAssertEqual(plan.notes, [.customStereoUnavailable])
        XCTAssertEqual(plan.sourceRegion, IPaVisionRect(x: 0, y: 0, width: 1, height: 0.5))
    }

    // MARK: Automatic routes (system renderer)

    /// Regression: automatic Apple Immersive / parametric / unnamed
    /// non-rectilinear media used to be planned `.flat`, which the renderer
    /// shows in a portal. It must stay a distinct immersive projection.
    func testAutomaticSystemOnlyImmersiveIsNeverFlattened() {
        for projection: Meta.Projection in [.appleImmersive, .parametricImmersive, .otherNonRectilinear] {
            for packing: Meta.Packing in [.mono, .multiview, .sideBySide] {
                let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: projection, packing: packing),
                                                    correction: .automatic)
                XCTAssertEqual(plan.backend, .system, "\(projection)")
                XCTAssertEqual(plan.projection, .systemImmersive, "\(projection) \(packing) was flattened")
                XCTAssertEqual(plan.notes, [])
                XCTAssertTrue(projection.isSystemOnlyImmersive)
            }
        }
    }

    func testAutomaticRoutesPerProjection() {
        let expected: [(Meta.Projection?, IPaVisionRenderPlan.Projection)] = [
            (.equirectangular, .equirectangular360),
            (.halfEquirectangular, .equirectangular180),
            (.appleImmersive, .systemImmersive),
            (.parametricImmersive, .systemImmersive),
            (.otherNonRectilinear, .systemImmersive),
            (.rectilinear, .flat),
            (nil, .flat),
        ]
        for (source, planned) in expected {
            let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: source), correction: .automatic)
            XCTAssertEqual(plan.projection, planned, "\(String(describing: source))")
        }
    }

    func testClassifiedAppleAndParametricTagsRouteToSystemImmersive() {
        for kind in [Value.appleImmersiveVideo, Value.parametricImmersive] {
            let meta = Meta.classify(projectionKinds: [kind], packingKinds: [], isMultiview: false,
                                     flaggedNonRectilinear: true)
            XCTAssertEqual(IPaVisionRenderPlan.make(metadata: meta, correction: .automatic).projection,
                           .systemImmersive, kind)
        }
    }

    func testSystemImmersiveHasNoCustomGeometry() {
        XCTAssertEqual(IPaVisionRenderPlan.Projection.systemImmersive.customGeometry, .flat)
        XCTAssertEqual(IPaVisionRenderPlan.Projection.equirectangular360.customGeometry, .equirectangular360)
        XCTAssertEqual(IPaVisionRenderPlan.Projection.equirectangular180.customGeometry, .equirectangular180)
    }

    // MARK: Manual corrections (custom renderer)

    func testManualCorrectionOfSystemOnlyImmersiveFallsBackWithNote() {
        for projection: Meta.Projection in [.appleImmersive, .parametricImmersive] {
            let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: projection),
                                                correction: IPaVisionCorrection(zoom: 1.5))
            XCTAssertEqual(plan.backend, .customMono)
            XCTAssertEqual(plan.projection, .flat)
            XCTAssertEqual(plan.notes, [.unsupportedSourceProjection])
        }
    }

    func testUnmappableProjectionIsNoted() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .otherNonRectilinear),
                                            correction: IPaVisionCorrection(zoom: 2))
        XCTAssertEqual(plan.projection, .flat)
        XCTAssertEqual(plan.notes, [.unsupportedSourceProjection])
    }

    func testMultiviewRendersPrimaryViewMono() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear, packing: .multiview),
                                            correction: IPaVisionCorrection(zoom: 1.2))
        XCTAssertEqual(plan.backend, .customMono)
        XCTAssertEqual(plan.stereoLayout, .mono)
        // Manual correction of MV-HEVC: one decoded view → must be flagged.
        XCTAssertTrue(plan.stereoShownAsMono)
        XCTAssertTrue(plan.isMonoDowngrade)
        XCTAssertEqual(plan.notes, [.multiviewShownAsMono])
    }

    // MARK: Ineffective controls never downgrade silently

    func testConvergenceAloneKeepsTheSystemRenderer() {
        for meta in [Meta(projection: .rectilinear, packing: .multiview),
                     Meta(projection: .halfEquirectangular, packing: .sideBySide),
                     Meta(projection: .rectilinear)] {
            let plan = IPaVisionRenderPlan.make(metadata: meta, correction: IPaVisionCorrection(convergence: 2))
            XCTAssertEqual(plan.backend, .system, "\(meta)")
            XCTAssertFalse(plan.isMonoDowngrade)
            XCTAssertEqual(plan.notes, [.convergenceIgnored])
            XCTAssertEqual(plan.correction.convergence, 0)
        }
    }

    func testEyeSwapOnAMonoOrMultiviewLayoutIsIgnored() {
        for meta in [Meta(projection: .rectilinear, packing: .multiview), Meta(projection: .equirectangular)] {
            let plan = IPaVisionRenderPlan.make(metadata: meta,
                                                correction: IPaVisionCorrection(swapsEyes: true, splitRatio: 0.6))
            XCTAssertEqual(plan.backend, .system, "\(meta)")
            XCTAssertFalse(plan.isMonoDowngrade)
            XCTAssertEqual(plan.notes, [.packingControlsIgnored])
        }
        // Convergence + swap together on MV-HEVC: still the system renderer.
        let both = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear, packing: .multiview),
                                            correction: IPaVisionCorrection(swapsEyes: true, convergence: -1))
        XCTAssertEqual(both.backend, .system)
        XCTAssertEqual(both.notes, [.convergenceIgnored, .packingControlsIgnored])
    }

    func testEyeSwapOnAPackedLayoutIsAnExplicitMonoDowngrade() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .halfEquirectangular, packing: .sideBySide),
                                            correction: IPaVisionCorrection(swapsEyes: true))
        XCTAssertEqual(plan.backend, .customMono)
        XCTAssertTrue(plan.isMonoDowngrade)
        XCTAssertEqual(plan.notes, [.customStereoUnavailable])
        XCTAssertEqual(plan.sourceRegion, IPaVisionRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testIgnoredControlsAreDroppedFromAnEffectiveCorrection() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear, packing: .multiview),
                                            correction: IPaVisionCorrection(swapsEyes: true, yaw: 20, convergence: 3))
        XCTAssertEqual(plan.backend, .customMono)
        XCTAssertEqual(plan.correction, IPaVisionCorrection(yaw: 20))
        XCTAssertEqual(plan.notes, [.convergenceIgnored, .packingControlsIgnored, .multiviewShownAsMono])
        XCTAssertTrue(plan.isMonoDowngrade)
    }

    func testMonoSourceWithManualCorrectionIsNotADowngrade() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear),
                                            correction: IPaVisionCorrection(projection: .equirectangular180))
        XCTAssertEqual(plan.backend, .customMono)
        XCTAssertFalse(plan.isMonoDowngrade)
    }

    func testAvailableStereoBackendDropsTheNote() {
        let plan = IPaVisionRenderPlan.make(metadata: Meta(projection: .rectilinear),
                                            correction: IPaVisionCorrection(stereoLayout: .sideBySide),
                                            stereoBackend: .available)
        XCTAssertEqual(plan.notes, [])
        XCTAssertFalse(IPaVisionStereoBackend.current.isAvailable)
    }

    func testSourceRegionsSplitAndSwap() {
        let sbs = IPaVisionCorrection(splitRatio: 0.6)
        XCTAssertEqual(IPaVisionRenderPlan.sourceRegion(layout: .sideBySide, correction: sbs, eye: .left),
                       IPaVisionRect(x: 0, y: 0, width: 0.6, height: 1))
        let right = IPaVisionRenderPlan.sourceRegion(layout: .sideBySide, correction: sbs, eye: .right)
        XCTAssertEqual(right.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(right.width, 0.4, accuracy: 1e-9)
        let swapped = IPaVisionCorrection(swapsEyes: true)
        XCTAssertEqual(IPaVisionRenderPlan.sourceRegion(layout: .overUnder, correction: swapped, eye: .left),
                       IPaVisionRect(x: 0, y: 0.5, width: 1, height: 0.5))
        XCTAssertEqual(IPaVisionRenderPlan.sourceRegion(layout: .mono, correction: swapped, eye: .left), .unit)
    }
}
