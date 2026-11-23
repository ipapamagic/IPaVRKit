//
//  IPaVisionImmersiveScene.swift
//  IPaVisionKit
//
//  The entity graph of one immersive playback: a root at eye height holding
//  the video entity, the scrub input shell and the scrub HUD. It rebuilds the
//  video entity only when the geometry changes, and re-orients it in place
//  for yaw / pitch / roll / horizon-lock edits.
//

#if os(visionOS)
import AVFoundation
import Observation
import RealityKit
import IPaVisionKitCore

@MainActor
@Observable
public final class IPaVisionImmersiveScene {
    /// ImmersiveSpace coordinates start at the floor below the viewer; the
    /// content is centred on a typical seated/standing eye height.
    public static let eyeHeight: Float = 1.5

    public let root = Entity()
    public private(set) var plan: IPaVisionRenderPlan?
    public private(set) var scrubState: IPaVisionScrubCoordinator.State = .idle
    /// Briefly true after a pinch on a live / unknown item.
    public private(set) var showsScrubUnavailable = false
    public private(set) var lastError: String?

    @ObservationIgnored private var videoEntity: Entity?
    @ObservationIgnored private var shellEntity: Entity?
    @ObservationIgnored private var hudEntity: Entity?
    @ObservationIgnored private var monoNoticeEntity: Entity?
    @ObservationIgnored private var appliedKey: GeometryKey?
    @ObservationIgnored private var scrub: IPaVisionScrubCoordinator?
    @ObservationIgnored private var scrubStart: SIMD3<Float>?
    @ObservationIgnored private var unavailableHide: Task<Void, Never>?

    public init() {
        IPaVisionInputShellComponent.registerComponent()
        root.name = "IPaVision.root"
        root.position = SIMD3(0, Self.eyeHeight, 0)
    }

    /// Everything but orientation: a change here needs a new mesh / component.
    private struct GeometryKey: Equatable {
        var player: ObjectIdentifier
        var plan: IPaVisionRenderPlan
        var correction: IPaVisionCorrection
        var aspect: Double?
    }

    /// Shows `player` per `metadata` + `correction`. Cheap when only the
    /// orientation changed.
    public func apply(player: AVPlayer, metadata: IPaVisionSourceMetadata, correction rawCorrection: IPaVisionCorrection) {
        let plan = IPaVisionRenderPlan.make(metadata: metadata, correction: rawCorrection)
        // What is actually rendered: controls the plan ignores (convergence,
        // eye swap on a mono layout) neither rebuild nor re-orient anything.
        let correction = plan.correction
        var geometryOnly = correction
        geometryOnly.yaw = 0
        geometryOnly.pitch = 0
        geometryOnly.roll = 0
        geometryOnly.horizonLock = false
        var geometryPlan = plan
        geometryPlan.correction = geometryOnly
        let key = GeometryKey(player: ObjectIdentifier(player), plan: geometryPlan, correction: geometryOnly,
                              aspect: metadata.frameAspectRatio)
        if key != appliedKey {
            do {
                let entity = try IPaVisionRenderer.makeVideoEntity(plan: plan, player: player, correction: correction,
                                                                   frameAspectRatio: metadata.frameAspectRatio)
                videoEntity?.removeFromParent()
                root.addChild(entity)
                videoEntity = entity
                appliedKey = key
                lastError = nil
            } catch {
                lastError = String(describing: error)
            }
        }
        if plan.backend == .customMono {
            videoEntity?.orientation = IPaVisionGeometry.orientation(for: correction)
        }
        self.plan = plan
        refreshMonoNotice()
    }

    /// Adds the indirect-only input shell (once).
    public func installInputShell() async {
        guard shellEntity == nil else { return }
        do {
            let shell = try await IPaVisionRenderer.makeInputShell()
            guard shellEntity == nil else { return }
            root.addChild(shell)
            shellEntity = shell
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Places the SwiftUI attachment that shows scrub progress.
    public func attachHUD(_ entity: Entity) {
        guard hudEntity !== entity else { return }
        hudEntity?.removeFromParent()
        entity.components.set(BillboardComponent())
        entity.isEnabled = false
        root.addChild(entity)
        hudEntity = entity
    }

    /// Places the "shown in mono" badge; visible only while the plan is a
    /// mono downgrade of a stereo source.
    public func attachMonoNotice(_ entity: Entity) {
        guard monoNoticeEntity !== entity else { return }
        monoNoticeEntity?.removeFromParent()
        entity.components.set(BillboardComponent())
        entity.position = SIMD3(0, -0.45, -1.2)
        root.addChild(entity)
        monoNoticeEntity = entity
        refreshMonoNotice()
    }

    /// True while the current plan draws a stereo source mono.
    public var showsMonoDowngrade: Bool { plan?.isMonoDowngrade ?? false }

    private func refreshMonoNotice() {
        monoNoticeEntity?.isEnabled = showsMonoDowngrade
    }

    // MARK: Scrubbing

    public func bind(controller: any IPaVisionPlaybackControlling) {
        let coordinator = IPaVisionScrubCoordinator(controller: controller)
        coordinator.onStateChange = { [weak self] state in self?.scrubStateChanged(state) }
        scrub = coordinator
    }

    /// `startLocation` / `translation` are in scene (immersive space) metres.
    public func scrubChanged(startLocation: SIMD3<Float>, translation: SIMD3<Float>) {
        guard let scrub else { return }
        if scrubStart == nil {
            scrubStart = startLocation
            positionHUD(towards: startLocation)
            scrub.begin()
        }
        let metres = IPaVisionScrubMapping.horizontalDistance(translation: translation,
                                                              startLocation: startLocation,
                                                              viewer: root.position(relativeTo: nil))
        scrub.update(horizontalMetres: Double(metres))
    }

    public func scrubEnded() {
        scrubStart = nil
        scrub?.end()
    }

    public func scrubCancelled() {
        scrubStart = nil
        scrub?.cancel()
    }

    /// The gesture's state was reset (ended *or* cancelled by the system).
    /// `onEnded` runs around the same time; wait a turn so a normal end is
    /// handled as an end, and only an unfinished scrub is cancelled.
    public func scrubGestureReset() {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.scrubStart = nil
            self.scrub?.gestureDidReset()
        }
    }

    /// The immersive view disappeared: never leave a scrub (and the pause it
    /// started) behind.
    public func tearDown() {
        scrubStart = nil
        unavailableHide?.cancel()
        scrub?.tearDown()
    }

    private func scrubStateChanged(_ state: IPaVisionScrubCoordinator.State) {
        scrubState = state
        if case .unavailable = state {
            showsScrubUnavailable = true
            unavailableHide?.cancel()
            unavailableHide = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                self?.showsScrubUnavailable = false
                self?.refreshHUDVisibility()
            }
        }
        refreshHUDVisibility()
    }

    private func refreshHUDVisibility() {
        switch scrubState {
        case .scrubbing, .settling: hudEntity?.isEnabled = true
        case .unavailable: hudEntity?.isEnabled = true
        case .idle: hudEntity?.isEnabled = showsScrubUnavailable
        }
    }

    /// 0.9 m from the viewer towards where the pinch landed, a little low, so
    /// the readout appears where the user is looking.
    private func positionHUD(towards worldPoint: SIMD3<Float>) {
        guard let hudEntity else { return }
        let local = worldPoint - root.position(relativeTo: nil)
        var direction = SIMD3<Float>(local.x, 0, local.z)
        if simd_length(direction) < 1e-3 { direction = SIMD3(0, 0, -1) }
        hudEntity.position = simd_normalize(direction) * 0.9 + SIMD3(0, -0.25, 0)
    }
}
#endif
