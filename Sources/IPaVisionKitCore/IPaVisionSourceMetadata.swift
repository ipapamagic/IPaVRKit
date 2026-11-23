//
//  IPaVisionSourceMetadata.swift
//  IPaVisionKitCore
//
//  What a video *declares* about its geometry, and the render plan that
//  follows from it plus the user's correction.
//
//  Classification takes the raw CoreMedia strings (projection kind, view
//  packing kind) so it stays Foundation-only and testable on the host. The
//  visionOS target reads them from AVFoundation.
//

import Foundation

public struct IPaVisionSourceMetadata: Equatable, Hashable, Sendable {
    public enum Projection: Equatable, Hashable, Sendable {
        case rectilinear
        case equirectangular
        case halfEquirectangular
        /// Wide-FOV lens model / Apple Immersive / a kind this build doesn't
        /// name: not flat, but not something the custom renderer can map.
        case otherNonRectilinear
    }

    public enum Packing: Equatable, Hashable, Sendable {
        case mono
        /// MV-HEVC: the decoder delivers both eyes itself.
        case multiview
        case sideBySide
        case overUnder
    }

    /// nil when no video track was readable yet (e.g. HLS before ready).
    public var projection: Projection?
    public var packing: Packing
    /// Display aspect ratio of the whole frame (width / height), if known.
    public var frameAspectRatio: Double?

    public init(projection: Projection?, packing: Packing = .mono, frameAspectRatio: Double? = nil) {
        self.projection = projection
        self.packing = packing
        self.frameAspectRatio = frameAspectRatio.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    public static let undetermined = IPaVisionSourceMetadata(projection: nil)

    /// CoreMedia's `kCMFormatDescriptionProjectionKind_*` / `ViewPackingKind_*`
    /// string values, spelled out so the classification needs no CoreMedia.
    public enum CoreMediaValue {
        public static let rectilinear = "Rectilinear"
        public static let equirectangular = "Equirectangular"
        public static let halfEquirectangular = "HalfEquirectangular"
        public static let sideBySide = "SideBySide"
        public static let overUnder = "OverUnder"
    }

    /// Classifies the format-description values of a video track.
    /// - Parameters:
    ///   - projectionKinds: every `ProjectionKind` extension value found.
    ///   - packingKinds: every `ViewPackingKind` extension value found.
    ///   - isMultiview: the track has `containsStereoMultiviewVideo`.
    ///   - flaggedNonRectilinear: the track has `indicatesNonRectilinearProjection`.
    public static func classify(projectionKinds: [String],
                                packingKinds: [String],
                                isMultiview: Bool,
                                flaggedNonRectilinear: Bool,
                                frameAspectRatio: Double? = nil) -> IPaVisionSourceMetadata {
        var projection: Projection = flaggedNonRectilinear ? .otherNonRectilinear : .rectilinear
        for kind in projectionKinds {
            switch kind {
            case CoreMediaValue.rectilinear: projection = .rectilinear
            case CoreMediaValue.equirectangular: projection = .equirectangular
            case CoreMediaValue.halfEquirectangular: projection = .halfEquirectangular
            default: projection = .otherNonRectilinear
            }
        }
        var packing: Packing = isMultiview ? .multiview : .mono
        if packing == .mono {
            if packingKinds.contains(CoreMediaValue.sideBySide) {
                packing = .sideBySide
            } else if packingKinds.contains(CoreMediaValue.overUnder) {
                packing = .overUnder
            }
        }
        return IPaVisionSourceMetadata(projection: projection, packing: packing, frameAspectRatio: frameAspectRatio)
    }

    /// The system renderer has something to honour beyond a flat picture.
    public var isTaggedImmersiveOrStereo: Bool {
        guard let projection else { return false }
        return projection != .rectilinear || packing != .mono
    }
}

/// Which backend draws the video, and with which geometry.
public struct IPaVisionRenderPlan: Equatable, Sendable {
    public enum Backend: Equatable, Sendable {
        /// `VideoPlayerComponent`: the system reads the asset's own tags.
        case system
        /// Mesh + `VideoMaterial`; both eyes see the same (selected) view.
        case customMono
    }

    public enum Projection: Equatable, Sendable {
        case flat
        case equirectangular360
        case equirectangular180
    }

    public enum Eye: Equatable, Sendable { case left, right }

    public var backend: Backend
    /// Geometry for `.customMono`; for `.system` the best description of
    /// what the system will draw (informational).
    public var projection: Projection
    public var stereoLayout: IPaVisionCorrection.StereoLayout
    /// The source frame region, in image coordinates (origin top-left, y down,
    /// 0...1), that the custom renderer samples.
    public var sourceRegion: IPaVisionRect
    /// The correction carries stereo, but only mono rendering is available, so
    /// one eye is shown to both eyes.
    public var stereoShownAsMono: Bool
    /// Why `.customMono` could not render what was asked, if anything.
    public var notes: [Note]

    public enum Note: Equatable, Sendable {
        /// Custom stereo has no proven backend (see `IPaVisionStereoBackend`).
        case customStereoUnavailable
        /// The file's projection can't be re-mapped by the custom renderer;
        /// it falls back to the chosen / flat geometry.
        case unsupportedSourceProjection
    }

    /// Decides the backend: the system renderer whenever the correction is
    /// automatic, the custom mono renderer otherwise.
    public static func make(metadata: IPaVisionSourceMetadata,
                            correction rawCorrection: IPaVisionCorrection,
                            stereoBackend: IPaVisionStereoBackend = .current) -> IPaVisionRenderPlan {
        let correction = rawCorrection.clamped()
        let layout = resolvedLayout(metadata: metadata, correction: correction)
        let (projection, projectionNote) = resolvedProjection(metadata: metadata, correction: correction)

        if correction.isAutomatic {
            return IPaVisionRenderPlan(backend: .system,
                                       projection: projection,
                                       stereoLayout: layout,
                                       sourceRegion: .unit,
                                       stereoShownAsMono: false,
                                       notes: [])
        }
        var notes: [Note] = []
        if let projectionNote { notes.append(projectionNote) }
        let isStereo = layout == .sideBySide || layout == .overUnder
        if isStereo, !stereoBackend.isAvailable { notes.append(.customStereoUnavailable) }
        return IPaVisionRenderPlan(backend: .customMono,
                                   projection: projection,
                                   stereoLayout: layout,
                                   sourceRegion: sourceRegion(layout: layout, correction: correction, eye: .left),
                                   stereoShownAsMono: isStereo,
                                   notes: notes)
    }

    static func resolvedLayout(metadata: IPaVisionSourceMetadata,
                               correction: IPaVisionCorrection) -> IPaVisionCorrection.StereoLayout {
        switch correction.stereoLayout {
        case .auto:
            switch metadata.packing {
            case .sideBySide: return .sideBySide
            case .overUnder: return .overUnder
            // MV-HEVC decodes to the primary (left) view in a VideoMaterial.
            case .mono, .multiview: return .mono
            }
        case let explicit:
            return explicit
        }
    }

    static func resolvedProjection(metadata: IPaVisionSourceMetadata,
                                   correction: IPaVisionCorrection) -> (Projection, Note?) {
        switch correction.projection {
        case .flat: return (.flat, nil)
        case .equirectangular360: return (.equirectangular360, nil)
        case .equirectangular180: return (.equirectangular180, nil)
        case .auto:
            switch metadata.projection {
            case .equirectangular: return (.equirectangular360, nil)
            case .halfEquirectangular: return (.equirectangular180, nil)
            case .rectilinear, nil: return (.flat, nil)
            case .otherNonRectilinear: return (.flat, .unsupportedSourceProjection)
            }
        }
    }

    /// The region of the frame that holds `eye`, after the split ratio and
    /// the eye swap. (Zoom and offsets are applied inside this region by the
    /// mesh's texture coordinates, see `IPaVisionGeometry`.)
    public static func sourceRegion(layout: IPaVisionCorrection.StereoLayout,
                                    correction: IPaVisionCorrection,
                                    eye: Eye) -> IPaVisionRect {
        let c = correction.clamped()
        let s = c.splitRatio
        let first = (eye == .left) != c.swapsEyes
        let region: IPaVisionRect
        switch layout {
        case .sideBySide:
            region = first ? IPaVisionRect(x: 0, y: 0, width: s, height: 1)
                           : IPaVisionRect(x: s, y: 0, width: 1 - s, height: 1)
        case .overUnder:
            region = first ? IPaVisionRect(x: 0, y: 0, width: 1, height: s)
                           : IPaVisionRect(x: 0, y: s, width: 1, height: 1 - s)
        case .mono, .auto:
            region = .unit
        }
        return region
    }
}

/// A rectangle in normalised image coordinates.
public struct IPaVisionRect: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let unit = IPaVisionRect(x: 0, y: 0, width: 1, height: 1)

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
}

/// Availability of a per-eye (custom stereo) renderer.
///
/// RealityKit exposes no Swift API to pick a texture per eye. The known route
/// is a ShaderGraph material using Reality Composer Pro's *Camera Index
/// Switch* node, fed by frames pulled through `AVPlayerVideoOutput`. Neither
/// the node's behaviour nor whether `AVPlayerVideoOutput` may coexist with
/// `VideoMaterial` / `VideoPlayerComponent` on the same `AVPlayer` can be
/// verified without a real Vision Pro, so the backend is `.unsupported` and
/// stereo corrections render mono. See docs/PHASE0.md.
public enum IPaVisionStereoBackend: Equatable, Sendable {
    case unsupported(reason: String)
    case available

    public static let current: IPaVisionStereoBackend = .unsupported(
        reason: "Custom stereo (Camera Index Switch + AVPlayerVideoOutput) is unverified without Vision Pro hardware.")

    public var isAvailable: Bool { self == .available }
}
