import XCTest
import simd
@testable import IPaVisionKitCore

@MainActor
final class FakeTransport: IPaVisionPlaybackControlling {
    var currentTime: Double = 0
    var isPlaying = false
    var seekableRange: IPaVisionSeekableRange = .vod(duration: 600)
    var calls: [String] = []
    var seeks: [(Double, IPaVisionSeekPrecision)] = []

    func play() { isPlaying = true; calls.append("play") }
    func pause() { isPlaying = false; calls.append("pause") }
    func seek(to seconds: Double, precision: IPaVisionSeekPrecision) async -> Bool {
        seeks.append((seconds, precision))
        calls.append("seek:\(precision)")
        currentTime = seconds
        return true
    }
}

@MainActor
final class IPaVisionScrubTests: XCTestCase {
    func testSeekableRangeClassification() {
        XCTAssertEqual(IPaVisionSeekableRange.classify(durationSeconds: 120, isIndefinite: false), .vod(duration: 120))
        XCTAssertEqual(IPaVisionSeekableRange.classify(durationSeconds: .nan, isIndefinite: true), .live)
        XCTAssertEqual(IPaVisionSeekableRange.classify(durationSeconds: .nan, isIndefinite: false), .unknown)
        XCTAssertEqual(IPaVisionSeekableRange.classify(durationSeconds: 0, isIndefinite: false), .unknown)
        XCTAssertFalse(IPaVisionSeekableRange.live.isSeekable)
    }

    func testMappingRatesAndClamps() {
        let m = IPaVisionScrubMapping()
        XCTAssertEqual(m.secondsPerMetre(duration: 4), 10)            // floor
        XCTAssertEqual(m.secondsPerMetre(duration: 80), 100)
        XCTAssertEqual(m.secondsPerMetre(duration: 7200), 600)        // ceiling
        XCTAssertEqual(m.target(startTime: 30, metres: 0.005, duration: 80), 30)   // dead zone
        XCTAssertEqual(m.target(startTime: 30, metres: 0.11, duration: 80), 40, accuracy: 1e-9)
        XCTAssertEqual(m.target(startTime: 30, metres: -0.11, duration: 80), 20, accuracy: 1e-9)
        XCTAssertEqual(m.target(startTime: 30, metres: 5, duration: 80), 80)
        XCTAssertEqual(m.target(startTime: 30, metres: -5, duration: 80), 0)
        XCTAssertEqual(m.target(startTime: 30, metres: .nan, duration: 80), 30)
    }

    func testHorizontalDistanceFollowsTheFacingDirection() {
        // Facing forward (-Z): moving +X is right.
        XCTAssertEqual(IPaVisionScrubMapping.horizontalDistance(translation: [0.2, 0.5, 0], startLocation: [0, 1, -2]),
                       0.2, accuracy: 1e-6)
        // Facing right (+X): "right" is +Z.
        XCTAssertEqual(IPaVisionScrubMapping.horizontalDistance(translation: [0, 0, 0.3], startLocation: [2, 1, 0]),
                       0.3, accuracy: 1e-6)
        // Facing backwards (+Z): moving +X is to the viewer's left.
        XCTAssertEqual(IPaVisionScrubMapping.horizontalDistance(translation: [0.1, 0, 0], startLocation: [0, 0, 2]),
                       -0.1, accuracy: 1e-6)
        // Straight up / degenerate: falls back to x.
        XCTAssertEqual(IPaVisionScrubMapping.horizontalDistance(translation: [0.4, 0, 0], startLocation: [0, 2, 0]), 0.4)
    }

    func testThrottle() {
        var t = IPaVisionSeekThrottle(interval: 0.15)
        XCTAssertTrue(t.shouldFire(at: 1))
        XCTAssertFalse(t.shouldFire(at: 1.1))
        XCTAssertTrue(t.shouldFire(at: 1.2))
        t.reset()
        XCTAssertTrue(t.shouldFire(at: 1.21))
    }

    func testVODScrubPausesThrottlesSeeksExactlyAndResumes() async {
        let transport = FakeTransport()
        transport.currentTime = 100
        transport.isPlaying = true
        var now: TimeInterval = 0
        let scrub = IPaVisionScrubCoordinator(controller: transport, throttleInterval: 0.15, clock: { now })
        var states: [IPaVisionScrubCoordinator.State] = []
        scrub.onStateChange = { states.append($0) }

        XCTAssertTrue(scrub.begin())
        XCTAssertEqual(transport.calls, ["pause"])
        XCTAssertEqual(scrub.state, .scrubbing(target: 100, duration: 600))

        await scrub.update(horizontalMetres: 0.11)?.value          // 600/0.8 = 750 s/m → +75 s
        now = 0.05
        XCTAssertNil(scrub.update(horizontalMetres: 0.21))          // throttled
        now = 0.2
        await scrub.update(horizontalMetres: 0.31)?.value
        XCTAssertEqual(transport.seeks.map(\.1), [.fast, .fast])

        await scrub.end()?.value
        XCTAssertEqual(transport.seeks.last?.1, .exact)
        XCTAssertEqual(transport.seeks.last!.0, 100 + 0.30 * 600, accuracy: 1e-6)
        XCTAssertEqual(transport.calls.last, "play")                 // was playing → resumes
        XCTAssertEqual(scrub.state, .idle)
        XCTAssertEqual(states.first, .scrubbing(target: 100, duration: 600))
        XCTAssertTrue(states.contains { if case .settling = $0 { return true }; return false })
    }

    func testPausedPlaybackStaysPaused() async {
        let transport = FakeTransport()
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        XCTAssertTrue(scrub.begin())
        scrub.update(horizontalMetres: 0.1)
        await scrub.end()?.value
        XCTAssertFalse(transport.calls.contains("play"))
        XCTAssertFalse(transport.calls.contains("pause"))
        XCTAssertFalse(transport.isPlaying)
    }

    func testLiveAndUnknownNeverSeek() async {
        for range in [IPaVisionSeekableRange.live, .unknown] {
            let transport = FakeTransport()
            transport.isPlaying = true
            transport.seekableRange = range
            let scrub = IPaVisionScrubCoordinator(controller: transport)
            XCTAssertFalse(scrub.begin())
            XCTAssertEqual(scrub.state, .unavailable(range))
            XCTAssertNil(scrub.update(horizontalMetres: 1))
            XCTAssertNil(scrub.end())
            XCTAssertEqual(scrub.state, .idle)
            XCTAssertTrue(transport.calls.isEmpty, "\(range): \(transport.calls)")
            XCTAssertTrue(transport.isPlaying)
        }
    }

    func testCancelReturnsToTheStart() async {
        let transport = FakeTransport()
        transport.currentTime = 42
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        scrub.update(horizontalMetres: 0.5)
        await scrub.cancel()?.value
        XCTAssertEqual(transport.seeks.last?.0, 42)
        XCTAssertEqual(transport.seeks.last?.1, .exact)
    }

    func testANewDragDuringSettlingKeepsTheOriginalPlayingState() async {
        let transport = FakeTransport()
        transport.isPlaying = true
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        let settle = scrub.end()                // exact seek in flight, transport paused
        XCTAssertTrue(scrub.begin())            // re-grab before it lands
        await settle?.value                     // superseded: must not play or go idle
        XCTAssertFalse(transport.isPlaying)
        if case .scrubbing = scrub.state {} else { XCTFail("expected scrubbing, got \(scrub.state)") }
        await scrub.end()?.value
        XCTAssertTrue(transport.isPlaying)      // the original drag started while playing
    }

    // MARK: Cancellation / teardown never leave playback paused

    func testSystemCancelledGestureRestoresPositionAndPlayback() async {
        let transport = FakeTransport()
        transport.currentTime = 50
        transport.isPlaying = true
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        await scrub.update(horizontalMetres: 0.3)?.value
        XCTAssertFalse(transport.isPlaying)
        await scrub.gestureDidReset()?.value          // no onEnded: the system cancelled
        XCTAssertEqual(transport.seeks.last?.0, 50)
        XCTAssertEqual(transport.seeks.last?.1, .exact)
        XCTAssertTrue(transport.isPlaying)
        XCTAssertEqual(scrub.state, .idle)
    }

    func testGestureResetAfterANormalEndDoesNothing() async {
        let transport = FakeTransport()
        transport.isPlaying = true
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        scrub.update(horizontalMetres: 0.2)
        let settle = scrub.end()
        XCTAssertNil(scrub.gestureDidReset())         // settling: left alone
        await settle?.value
        XCTAssertNil(scrub.gestureDidReset())         // idle: nothing to do
        XCTAssertEqual(transport.seeks.filter { $0.1 == .exact }.count, 1)
        XCTAssertTrue(transport.isPlaying)
    }

    func testGestureResetOnLiveClearsTheUnavailableState() {
        let transport = FakeTransport()
        transport.isPlaying = true
        transport.seekableRange = .live
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        XCTAssertNil(scrub.gestureDidReset())
        XCTAssertEqual(scrub.state, .idle)
        XCTAssertTrue(transport.calls.isEmpty)
    }

    func testTearDownMidScrubResumesPlayback() async {
        let transport = FakeTransport()
        transport.isPlaying = true
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        await scrub.tearDown()?.value
        XCTAssertTrue(transport.isPlaying)
        XCTAssertEqual(scrub.state, .idle)
    }

    func testPlaybackResumesEvenIfTheCoordinatorIsGoneBeforeTheSeekLands() async {
        let transport = FakeTransport()
        transport.isPlaying = true
        var scrub: IPaVisionScrubCoordinator? = IPaVisionScrubCoordinator(controller: transport)
        scrub?.begin()
        let settle = scrub?.end()
        scrub = nil                                   // view torn down mid-settle
        await settle?.value
        XCTAssertTrue(transport.isPlaying, "a scrub left playback paused for good")
    }

    func testTearDownOfAPausedScrubKeepsItPaused() async {
        let transport = FakeTransport()
        let scrub = IPaVisionScrubCoordinator(controller: transport)
        scrub.begin()
        await scrub.tearDown()?.value
        XCTAssertFalse(transport.isPlaying)
        XCTAssertFalse(transport.calls.contains("play"))
    }
}
