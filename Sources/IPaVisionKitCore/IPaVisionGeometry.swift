//
//  IPaVisionGeometry.swift
//  IPaVisionKitCore
//
//  Mesh and orientation math for the custom renderer, as plain arrays so it
//  can be tested on the host. The visionOS target only wraps the result in a
//  `MeshDescriptor`.
//
//  Conventions (RealityKit): right-handed, +Y up, the viewer at the origin
//  looking down -Z, counter-clockwise front faces. Texture coordinates have
//  their origin at the bottom-left (v up), so image row y maps to v = 1 - y.
//

import Foundation
import simd

public struct IPaVisionMeshData: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var uvs: [SIMD2<Float>]
    public var indices: [UInt32]

    public init(positions: [SIMD3<Float>], uvs: [SIMD2<Float>], indices: [UInt32]) {
        self.positions = positions
        self.uvs = uvs
        self.indices = indices
    }
}

public enum IPaVisionGeometry {
    /// Radius of the spherical video surface, in metres.
    public static let sphereRadius: Float = 20
    /// Distance of the flat screen, in metres.
    public static let flatDistance: Float = 4
    /// Widest angle a flat plane may span (a plane can't reach 180°).
    public static let flatMaxAngle: Double = 150
    /// Aspect ratio assumed when the source didn't report one.
    public static let defaultFrameAspectRatio: Double = 16.0 / 9.0

    /// Native horizontal coverage of a projection, in degrees.
    public static func defaultFieldOfView(for projection: IPaVisionRenderPlan.Projection) -> Double {
        switch projection {
        case .flat: return 60
        // Informational only: the system draws these from the asset's tags.
        case .systemImmersive: return 180
        case .equirectangular360: return 360
        case .equirectangular180: return 180
        }
    }

    /// What the custom renderer draws for `plan` and `correction`.
    public struct Layout: Equatable, Sendable {
        /// Angular size actually drawn, in degrees.
        public var horizontalAngle: Double
        public var verticalAngle: Double
        /// Share of the eye image shown on each axis (< 1 when the zoomed
        /// picture would exceed the drawable angle and is cropped).
        public var shownWidth: Double
        public var shownHeight: Double
        /// Centre of the shown window in eye-image coordinates (0...1, y down).
        public var center: SIMD2<Double>
    }

    public static func layout(plan: IPaVisionRenderPlan,
                              correction rawCorrection: IPaVisionCorrection,
                              frameAspectRatio: Double?) -> Layout {
        let c = rawCorrection.clamped()
        let fov = c.fieldOfView ?? defaultFieldOfView(for: plan.projection.customGeometry)
        let magnified = fov * c.zoom
        let horizontalCap: Double
        let verticalNative: Double
        let verticalCap: Double
        switch plan.projection.customGeometry {
        case .equirectangular360, .equirectangular180:
            horizontalCap = 360
            verticalCap = 180
            // Equirectangular: the eye image spans 2:1 (360) or 1:1 (180)
            // degrees by definition.
            verticalNative = plan.projection.customGeometry == .equirectangular360 ? magnified / 2 : magnified
        case .flat, .systemImmersive:   // `customGeometry` never yields .systemImmersive
            horizontalCap = flatMaxAngle
            verticalCap = flatMaxAngle
            let aspect = eyeAspectRatio(region: plan.sourceRegion, frameAspectRatio: frameAspectRatio)
            // Angular height of a plane whose width spans `magnified`.
            let halfWidth = tan(radians(min(magnified, 179) / 2))
            verticalNative = degrees(2 * atan(halfWidth / aspect))
        }
        let horizontal = min(magnified, horizontalCap)
        let vertical = min(verticalNative, verticalCap)
        let shownWidth: Double
        let shownHeight: Double
        if plan.projection.customGeometry == .flat {
            shownWidth = magnified > horizontalCap
                ? tan(radians(horizontal / 2)) / tan(radians(min(magnified, 179) / 2)) : 1
            shownHeight = verticalNative > verticalCap
                ? tan(radians(vertical / 2)) / tan(radians(min(verticalNative, 179) / 2)) : 1
        } else {
            shownWidth = magnified > horizontalCap ? horizontalCap / magnified : 1
            shownHeight = verticalNative > verticalCap ? verticalCap / verticalNative : 1
        }
        return Layout(horizontalAngle: horizontal,
                      verticalAngle: vertical,
                      shownWidth: shownWidth,
                      shownHeight: shownHeight,
                      center: SIMD2(0.5 + c.horizontalOffset, 0.5 + c.verticalOffset))
    }

    /// Width / height of one eye's image.
    public static func eyeAspectRatio(region: IPaVisionRect, frameAspectRatio: Double?) -> Double {
        let frame = frameAspectRatio.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? defaultFrameAspectRatio
        guard region.height > 0 else { return frame }
        return frame * region.width / region.height
    }

    /// The inward-facing video surface for the custom mono renderer.
    public static func mesh(plan: IPaVisionRenderPlan,
                            correction: IPaVisionCorrection,
                            frameAspectRatio: Double? = nil,
                            segments: Int = 64) -> IPaVisionMeshData {
        let layout = layout(plan: plan, correction: correction, frameAspectRatio: frameAspectRatio)
        let columns = max(1, plan.projection.customGeometry == .flat ? 1 : segments)
        let rows = max(1, plan.projection.customGeometry == .flat ? 1 : segments / 2)
        let region = plan.sourceRegion
        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity((columns + 1) * (rows + 1))
        uvs.reserveCapacity((columns + 1) * (rows + 1))

        let flatHalfWidth = Double(flatDistance) * tan(radians(layout.horizontalAngle / 2))
        let flatHalfHeight = Double(flatDistance) * tan(radians(layout.verticalAngle / 2))

        for j in 0...rows {
            let wy = Double(j) / Double(rows)          // 0 = top
            for i in 0...columns {
                let wx = Double(i) / Double(columns)   // 0 = left
                switch plan.projection.customGeometry {
                case .flat, .systemImmersive:
                    positions.append(SIMD3(Float((wx - 0.5) * 2 * flatHalfWidth),
                                           Float((0.5 - wy) * 2 * flatHalfHeight),
                                           -flatDistance))
                case .equirectangular360, .equirectangular180:
                    let longitude = radians((wx - 0.5) * layout.horizontalAngle)
                    let latitude = radians((0.5 - wy) * layout.verticalAngle)
                    positions.append(SIMD3(Float(cos(latitude) * sin(longitude)),
                                           Float(sin(latitude)),
                                           Float(-cos(latitude) * cos(longitude))) * sphereRadius)
                }
                let ex = clampUnit(layout.center.x + (wx - 0.5) * layout.shownWidth)
                let ey = clampUnit(layout.center.y + (wy - 0.5) * layout.shownHeight)
                let imageX = region.x + ex * region.width
                let imageY = region.y + ey * region.height
                uvs.append(SIMD2(Float(imageX), Float(1 - imageY)))
            }
        }
        return IPaVisionMeshData(positions: positions,
                                 uvs: uvs,
                                 indices: gridIndices(columns: columns, rows: rows))
    }

    /// Two counter-clockwise (seen from the origin) triangles per grid cell.
    static func gridIndices(columns: Int, rows: Int) -> [UInt32] {
        var indices: [UInt32] = []
        indices.reserveCapacity(columns * rows * 6)
        let stride = UInt32(columns + 1)
        for j in 0..<UInt32(rows) {
            for i in 0..<UInt32(columns) {
                let a = j * stride + i          // top-left
                let b = a + 1                   // top-right
                let c = a + stride              // bottom-left
                let d = c + 1                   // bottom-right
                indices += [a, c, b, b, c, d]
            }
        }
        return indices
    }

    /// Rotation for the video entity: roll, then pitch, then yaw. Positive yaw
    /// turns the picture's centre to the viewer's right, positive pitch up,
    /// positive roll clockwise. Horizon lock drops the roll.
    public static func orientation(for rawCorrection: IPaVisionCorrection) -> simd_quatf {
        let c = rawCorrection.clamped()
        let yaw = simd_quatf(angle: Float(radians(-c.yaw)), axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: Float(radians(c.pitch)), axis: SIMD3(1, 0, 0))
        let roll = simd_quatf(angle: Float(radians(-c.effectiveRoll)), axis: SIMD3(0, 0, 1))
        return simd_normalize(yaw * pitch * roll)
    }

    // MARK: Input shell

    /// An invisible, inward-facing sphere around the viewer used only as a
    /// collision target, so an indirect pinch hits it wherever the user looks.
    /// UInt16 indices: `ShapeResource.generateStaticMesh` takes those.
    public static func inputShell(radius: Float = 2.5,
                                  columns: Int = 24,
                                  rows: Int = 12) -> (positions: [SIMD3<Float>], indices: [UInt16]) {
        var positions: [SIMD3<Float>] = []
        for j in 0...rows {
            let latitude = Double.pi / 2 - Double.pi * Double(j) / Double(rows)
            for i in 0...columns {
                let longitude = 2 * Double.pi * Double(i) / Double(columns) - Double.pi
                positions.append(SIMD3(Float(cos(latitude) * sin(longitude)),
                                       Float(sin(latitude)),
                                       Float(-cos(latitude) * cos(longitude))) * radius)
            }
        }
        let indices = gridIndices(columns: columns, rows: rows).map { UInt16($0) }
        return (positions, indices)
    }

    // MARK: Helpers

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    static func clampUnit(_ value: Double) -> Double { min(max(value, 0), 1) }
}
