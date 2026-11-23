//
//  IPaVisionRenderer.swift
//  IPaVisionKit
//
//  Builds the video entity for a render plan:
//    - `.system`: `VideoPlayerComponent`. The system reads the asset's own
//      projection / stereo tags (APMP 180/360, MV-HEVC, tagged SBS/OU) and
//      renders them as tagged, both eyes included.
//    - `.customMono`: a mesh from `IPaVisionGeometry` with a `VideoMaterial`.
//      Both eyes see the same view (the selected eye of a packed frame).
//
//  The AVPlayer is only a *source* here: nothing in this file plays, pauses
//  or seeks it.
//

#if os(visionOS)
import AVFoundation
import RealityKit
import IPaVisionKitCore

@MainActor
public enum IPaVisionRenderer {
    /// Width (metres) of the system flat screen at `systemScreenDistance`.
    public static let systemScreenWidth: Float = 3
    public static let systemScreenDistance: Float = 4

    /// A new entity drawing `player` according to `plan`. Its orientation is
    /// set from `correction` (identity for `.system`).
    public static func makeVideoEntity(plan: IPaVisionRenderPlan,
                                       player: AVPlayer,
                                       correction: IPaVisionCorrection,
                                       frameAspectRatio: Double?) throws -> Entity {
        switch plan.backend {
        case .system:
            return makeSystemEntity(plan: plan, player: player)
        case .customMono:
            return try makeCustomMonoEntity(plan: plan, player: player,
                                            correction: correction, frameAspectRatio: frameAspectRatio)
        }
    }

    static func makeSystemEntity(plan: IPaVisionRenderPlan, player: AVPlayer) -> Entity {
        let entity = Entity()
        entity.name = "IPaVision.system"
        var component = VideoPlayerComponent(avPlayer: player)
        switch plan.projection {
        case .equirectangular360, .equirectangular180:
            // Tagged immersive media fills the space around the viewer.
            component.desiredImmersiveViewingMode = .full
        case .flat:
            component.desiredImmersiveViewingMode = .portal
            // The component's screen is 1 m wide; scale it to the theatre size.
            entity.scale = SIMD3(repeating: systemScreenWidth)
            entity.position = SIMD3(0, 0, -systemScreenDistance)
        }
        entity.components.set(component)
        return entity
    }

    static func makeCustomMonoEntity(plan: IPaVisionRenderPlan,
                                     player: AVPlayer,
                                     correction: IPaVisionCorrection,
                                     frameAspectRatio: Double?) throws -> Entity {
        let data = IPaVisionGeometry.mesh(plan: plan, correction: correction, frameAspectRatio: frameAspectRatio)
        let mesh = try MeshResource.generate(from: [descriptor(for: data)])
        let entity = ModelEntity(mesh: mesh, materials: [VideoMaterial(avPlayer: player)])
        entity.name = "IPaVision.customMono"
        entity.orientation = IPaVisionGeometry.orientation(for: correction)
        return entity
    }

    static func descriptor(for data: IPaVisionMeshData) -> MeshDescriptor {
        var descriptor = MeshDescriptor(name: "IPaVisionVideoSurface")
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(data.uvs)
        descriptor.primitives = .triangles(data.indices)
        return descriptor
    }

    /// The invisible, indirect-only collision shell that catches the scrub
    /// pinch wherever the user looks. It has no `ModelComponent`, so it is
    /// never drawn; it only needs a collision shape and an input target.
    public static func makeInputShell(radius: Float = 2.5) async throws -> Entity {
        let shell = IPaVisionGeometry.inputShell(radius: radius)
        let shape = try await ShapeResource.generateStaticMesh(positions: shell.positions, faceIndices: shell.indices)
        let entity = Entity()
        entity.name = IPaVisionInputShellComponent.entityName
        entity.components.set(CollisionComponent(shapes: [shape], isStatic: true))
        entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        entity.components.set(IPaVisionInputShellComponent())
        return entity
    }
}

/// Marks the scrub input shell, so the gesture ignores every other entity.
public struct IPaVisionInputShellComponent: Component {
    public static let entityName = "IPaVision.inputShell"
    public init() {}
}

/// The custom per-eye renderer is deliberately not implemented.
///
/// Phase-0 could not verify, on this machine, either piece it would need:
///  1. Reality Composer Pro's ShaderGraph *Camera Index Switch* node (the only
///     known way to give each eye a different texture in RealityKit; there is
///     no Swift API for it in the visionOS 27.2 SDK), and
///  2. whether `AVPlayerVideoOutput` (the source of per-frame textures) may be
///     attached to the same `AVPlayer` while `VideoMaterial` /
///     `VideoPlayerComponent` also draw it, or must be exclusive.
/// The simulator renders a single view, so neither can be proven without a
/// Vision Pro. Until then this backend reports `.unsupported` and stereo
/// corrections are drawn by the mono renderer (one eye to both eyes).
public enum IPaVisionCustomStereoBackend {
    public static var status: IPaVisionStereoBackend { .current }

    /// Always nil while `status` is `.unsupported`.
    @MainActor
    public static func makeEntity(plan: IPaVisionRenderPlan, player: AVPlayer) -> Entity? {
        guard status.isAvailable else { return nil }
        return nil
    }
}
#endif
