import XCTest
import simd
@testable import IPaVisionKitCore

final class IPaVisionGeometryTests: XCTestCase {
    private func plan(_ projection: IPaVisionCorrection.Projection,
                      _ layout: IPaVisionCorrection.StereoLayout = .mono,
                      correction: IPaVisionCorrection? = nil) -> (IPaVisionRenderPlan, IPaVisionCorrection) {
        let c = correction ?? IPaVisionCorrection(projection: projection, stereoLayout: layout)
        return (IPaVisionRenderPlan.make(metadata: .init(projection: .rectilinear), correction: c), c)
    }

    private func assertFacesInward(_ mesh: IPaVisionMeshData, file: StaticString = #filePath, line: UInt = #line) {
        var checked = 0
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let p0 = mesh.positions[Int(mesh.indices[t])]
            let p1 = mesh.positions[Int(mesh.indices[t + 1])]
            let p2 = mesh.positions[Int(mesh.indices[t + 2])]
            // Pole triangles collapse two vertices onto the pole: skip them.
            guard simd_distance(p0, p1) > 1e-3, simd_distance(p1, p2) > 1e-3, simd_distance(p0, p2) > 1e-3 else { continue }
            let normal = simd_cross(p1 - p0, p2 - p0)
            let centroid = (p0 + p1 + p2) / 3
            XCTAssertLessThan(simd_dot(normal, centroid), 0, "triangle \(t / 3) faces away", file: file, line: line)
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0, file: file, line: line)
    }

    func testSphere360CoversTheWholeSphereFacingInward() {
        let (p, c) = plan(.equirectangular360)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c, segments: 16)
        XCTAssertEqual(mesh.positions.count, 17 * 9)
        XCTAssertEqual(mesh.uvs.count, mesh.positions.count)
        XCTAssertEqual(mesh.indices.count, 16 * 8 * 6)
        for position in mesh.positions {
            XCTAssertEqual(simd_length(position), IPaVisionGeometry.sphereRadius, accuracy: 1e-3)
        }
        assertFacesInward(mesh)
        // Centre of the picture is straight ahead, its top up, its left to the left.
        let center = mesh.positions[4 * 17 + 8]
        XCTAssertEqual(center.z, -IPaVisionGeometry.sphereRadius, accuracy: 1e-3)
        XCTAssertEqual(mesh.uvs[4 * 17 + 8].x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(mesh.uvs[4 * 17 + 8].y, 0.5, accuracy: 1e-6)
        XCTAssertEqual(mesh.uvs[0].y, 1, accuracy: 1e-6)          // top row → v = 1
        XCTAssertGreaterThan(mesh.positions[0].y, 19)              // top row at the zenith
    }

    func testHemisphere180SpansFrontHalf() {
        let (p, c) = plan(.equirectangular180)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c, segments: 8)
        let xs = mesh.positions.map(\.x)
        XCTAssertEqual(xs.min()!, -IPaVisionGeometry.sphereRadius, accuracy: 1e-3)
        XCTAssertEqual(xs.max()!, IPaVisionGeometry.sphereRadius, accuracy: 1e-3)
        XCTAssertTrue(mesh.positions.allSatisfy { $0.z <= 1e-3 })
        assertFacesInward(mesh)
    }

    func testFlatScreenSizeFollowsFieldOfViewAndAspect() {
        let c = IPaVisionCorrection(projection: .flat, fieldOfView: 90)
        let (p, _) = plan(.flat, correction: c)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c, frameAspectRatio: 2)
        XCTAssertEqual(mesh.positions.count, 4)
        let width = mesh.positions.map(\.x).max()! - mesh.positions.map(\.x).min()!
        let height = mesh.positions.map(\.y).max()! - mesh.positions.map(\.y).min()!
        XCTAssertEqual(width, 2 * IPaVisionGeometry.flatDistance, accuracy: 1e-3)   // tan(45°) = 1
        XCTAssertEqual(width / height, 2, accuracy: 1e-3)
        assertFacesInward(mesh)
    }

    func testSideBySideUsesTheSelectedHalf() {
        let (p, c) = plan(.flat, .sideBySide)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c)
        XCTAssertEqual(mesh.uvs.map(\.x).min()!, 0, accuracy: 1e-6)
        XCTAssertEqual(mesh.uvs.map(\.x).max()!, 0.5, accuracy: 1e-6)
        // The eye image is half as wide as the frame.
        XCTAssertEqual(IPaVisionGeometry.eyeAspectRatio(region: p.sourceRegion, frameAspectRatio: 32.0 / 9.0),
                       16.0 / 9.0, accuracy: 1e-9)

        let swapped = IPaVisionCorrection(projection: .flat, stereoLayout: .sideBySide, swapsEyes: true)
        let (sp, _) = plan(.flat, correction: swapped)
        let swappedMesh = IPaVisionGeometry.mesh(plan: sp, correction: swapped)
        XCTAssertEqual(swappedMesh.uvs.map(\.x).min()!, 0.5, accuracy: 1e-6)
        XCTAssertEqual(swappedMesh.uvs.map(\.x).max()!, 1, accuracy: 1e-6)
    }

    func testOverUnderTopEyeMapsToUpperTexture() {
        let (p, c) = plan(.equirectangular360, .overUnder)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c, segments: 8)
        XCTAssertEqual(mesh.uvs.map(\.y).min()!, 0.5, accuracy: 1e-6)
        XCTAssertEqual(mesh.uvs.map(\.y).max()!, 1, accuracy: 1e-6)
    }

    func testZoomBeyondTheCapCropsTheImage() {
        let c = IPaVisionCorrection(projection: .equirectangular360, zoom: 2)
        let (p, _) = plan(.equirectangular360, correction: c)
        let layout = IPaVisionGeometry.layout(plan: p, correction: c, frameAspectRatio: nil)
        XCTAssertEqual(layout.horizontalAngle, 360)
        XCTAssertEqual(layout.shownWidth, 0.5, accuracy: 1e-9)
        XCTAssertEqual(layout.shownHeight, 0.5, accuracy: 1e-9)

        let small = IPaVisionCorrection(projection: .equirectangular180, zoom: 0.5)
        let (sp, _) = plan(.equirectangular180, correction: small)
        let smallLayout = IPaVisionGeometry.layout(plan: sp, correction: small, frameAspectRatio: nil)
        XCTAssertEqual(smallLayout.horizontalAngle, 90)
        XCTAssertEqual(smallLayout.shownWidth, 1)
    }

    func testOffsetsShiftTextureButStayInsideTheEye() {
        let c = IPaVisionCorrection(projection: .flat, stereoLayout: .sideBySide, horizontalOffset: 0.5)
        let (p, _) = plan(.flat, correction: c)
        let mesh = IPaVisionGeometry.mesh(plan: p, correction: c)
        XCTAssertTrue(mesh.uvs.allSatisfy { $0.x >= 0 && $0.x <= 0.5 + 1e-6 })
        XCTAssertEqual(mesh.uvs.map(\.x).min()!, 0.25, accuracy: 1e-6)
    }

    func testOrientation() {
        func center(_ c: IPaVisionCorrection) -> SIMD3<Float> {
            IPaVisionGeometry.orientation(for: c).act(SIMD3<Float>(0, 0, -1))
        }
        XCTAssertEqual(center(IPaVisionCorrection(yaw: 90)).x, 1, accuracy: 1e-5)      // right
        XCTAssertEqual(center(IPaVisionCorrection(pitch: 30)).y, 0.5, accuracy: 1e-5)  // up
        let up = IPaVisionGeometry.orientation(for: IPaVisionCorrection(roll: 90)).act(SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(up.x, 1, accuracy: 1e-5)                                         // clockwise
        let locked = IPaVisionGeometry.orientation(for: IPaVisionCorrection(roll: 90, horizonLock: true))
        XCTAssertEqual(locked.act(SIMD3<Float>(0, 1, 0)).y, 1, accuracy: 1e-5)
    }

    func testInputShellSurroundsTheViewerFacingInward() {
        let shell = IPaVisionGeometry.inputShell(radius: 2.5, columns: 12, rows: 6)
        XCTAssertLessThan(shell.positions.count, Int(UInt16.max))
        XCTAssertTrue(shell.positions.allSatisfy { abs(simd_length($0) - 2.5) < 1e-3 })
        let mesh = IPaVisionMeshData(positions: shell.positions, uvs: [], indices: shell.indices.map(UInt32.init))
        assertFacesInward(mesh)
    }
}
