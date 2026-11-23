import XCTest
@testable import IPaVisionKitCore

final class IPaVisionCorrectionTests: XCTestCase {
    func testDefaultIsAutomatic() {
        XCTAssertTrue(IPaVisionCorrection().isAutomatic)
        XCTAssertEqual(IPaVisionCorrection.automatic, IPaVisionCorrection())
    }

    func testAnyOverrideIsNotAutomatic() {
        XCTAssertFalse(IPaVisionCorrection(projection: .flat).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(stereoLayout: .mono).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(swapsEyes: true).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(yaw: 10).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(horizonLock: true).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(convergence: 1).isAutomatic)
        XCTAssertFalse(IPaVisionCorrection(fieldOfView: 90).isAutomatic)
    }

    func testHardClamping() {
        let c = IPaVisionCorrection(splitRatio: 2, fieldOfView: 9999, zoom: -3, yaw: 720, pitch: -500,
                                    roll: 400, horizontalOffset: 4, verticalOffset: -4, convergence: 100)
        XCTAssertEqual(c.splitRatio, 0.75)
        XCTAssertEqual(c.fieldOfView, 360)
        XCTAssertEqual(c.zoom, 0.5)
        XCTAssertEqual(c.yaw, 180)
        XCTAssertEqual(c.pitch, -90)
        XCTAssertEqual(c.roll, 180)
        XCTAssertEqual(c.horizontalOffset, 0.5)
        XCTAssertEqual(c.verticalOffset, -0.5)
        XCTAssertEqual(c.convergence, 5)
    }

    func testMutationIsReclampedByClamped() {
        var c = IPaVisionCorrection()
        c.zoom = .infinity
        c.yaw = .nan
        c.splitRatio = 0
        let clamped = c.clamped()
        XCTAssertEqual(clamped.zoom, 1)      // non-finite → default
        XCTAssertEqual(clamped.yaw, 0)
        XCTAssertEqual(clamped.splitRatio, 0.25)
    }

    func testResetToAuto() {
        var c = IPaVisionCorrection(projection: .equirectangular180, stereoLayout: .sideBySide, yaw: 30)
        c.resetToAuto()
        XCTAssertTrue(c.isAutomatic)
    }

    func testHorizonLockDropsRoll() {
        XCTAssertEqual(IPaVisionCorrection(roll: 20, horizonLock: true).effectiveRoll, 0)
        XCTAssertEqual(IPaVisionCorrection(roll: 20).effectiveRoll, 20)
    }

    func testCodableRoundTrip() throws {
        let c = IPaVisionCorrection(projection: .equirectangular360, stereoLayout: .overUnder, swapsEyes: true,
                                    splitRatio: 0.6, fieldOfView: 200, zoom: 1.5, yaw: -30, pitch: 10, roll: 5,
                                    horizonLock: true, horizontalOffset: 0.1, verticalOffset: -0.1, convergence: 1)
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(IPaVisionCorrection.self, from: data), c)
    }

    func testDecodingIsTolerantAndClamps() throws {
        let json = #"{"projection":"hologram","stereoLayout":"sideBySide","zoom":50,"yaw":"x","future":1}"#
        let c = try JSONDecoder().decode(IPaVisionCorrection.self, from: Data(json.utf8))
        XCTAssertEqual(c.projection, .auto)          // unknown enum value
        XCTAssertEqual(c.stereoLayout, .sideBySide)
        XCTAssertEqual(c.zoom, 3)                    // clamped
        XCTAssertEqual(c.yaw, 0)                     // wrong type → default
        XCTAssertTrue(try JSONDecoder().decode(IPaVisionCorrection.self, from: Data("{}".utf8)).isAutomatic)
    }

    func testEncodingWritesVersion() throws {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(IPaVisionCorrection())) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, IPaVisionCorrection.currentVersion)
    }
}
