//
//  IPaVisionScrub.swift
//  IPaVisionKitCore
//
//  Horizontal pinch-drag scrubbing, independent of where the user looks.
//
//  The package owns no transport state. Every play / pause / seek goes through
//  `IPaVisionPlaybackControlling`, which the host app implements (KPPlayer
//  forwards it to IPaAVPlayer). The coordinator here only decides *when* and
//  *where* to seek:
//    - scrubbing is refused unless the item has a finite, known duration
//      (live and unknown ranges are never seeked);
//    - while dragging, fast (keyframe-tolerant) seeks are throttled;
//    - on release, one exact seek lands on the final target;
//    - playback resumes afterwards only if it was playing when the drag began.
//

import Foundation
import simd

/// What can be seeked in the current item.
public enum IPaVisionSeekableRange: Equatable, Sendable {
    /// A finite duration in seconds.
    case vod(duration: Double)
    /// An open-ended live stream.
    case live
    /// Not known yet (nothing loaded, or the duration isn't available).
    case unknown

    /// Classifies an item's duration. `isIndefinite` is `CMTime.isIndefinite`
    /// (how AVFoundation reports a live stream's duration).
    public static func classify(durationSeconds: Double, isIndefinite: Bool) -> IPaVisionSeekableRange {
        if isIndefinite { return .live }
        guard durationSeconds.isFinite, durationSeconds > 0 else { return .unknown }
        return .vod(duration: durationSeconds)
    }

    public var duration: Double? {
        if case let .vod(duration) = self { return duration }
        return nil
    }

    public var isSeekable: Bool { duration != nil }
}

public enum IPaVisionSeekPrecision: Equatable, Sendable {
    /// Keyframe-tolerant; for live feedback while dragging.
    case fast
    /// Frame-accurate; for the final position.
    case exact
}

/// The host's transport. All calls arrive on the main actor.
@MainActor
public protocol IPaVisionPlaybackControlling: AnyObject {
    var currentTime: Double { get }
    var isPlaying: Bool { get }
    var seekableRange: IPaVisionSeekableRange { get }
    func play()
    func pause()
    /// Returns whether this seek landed (false if superseded or impossible).
    func seek(to seconds: Double, precision: IPaVisionSeekPrecision) async -> Bool
}

/// Hand movement → time.
public struct IPaVisionScrubMapping: Equatable, Sendable {
    /// Hand travel (metres) that would cover the whole duration, before the
    /// rate limits below apply.
    public var fullRangeDistance: Double
    public var minimumSecondsPerMetre: Double
    public var maximumSecondsPerMetre: Double
    /// Movement below this (metres) is ignored, so a pinch alone doesn't seek.
    public var deadZone: Double

    public init(fullRangeDistance: Double = 0.8,
                minimumSecondsPerMetre: Double = 10,
                maximumSecondsPerMetre: Double = 600,
                deadZone: Double = 0.01) {
        self.fullRangeDistance = fullRangeDistance
        self.minimumSecondsPerMetre = minimumSecondsPerMetre
        self.maximumSecondsPerMetre = maximumSecondsPerMetre
        self.deadZone = deadZone
    }

    public func secondsPerMetre(duration: Double) -> Double {
        guard duration.isFinite, duration > 0, fullRangeDistance > 0 else { return minimumSecondsPerMetre }
        return min(max(duration / fullRangeDistance, minimumSecondsPerMetre), maximumSecondsPerMetre)
    }

    /// Target time for a drag of `metres` (positive = right = forward) that
    /// started at `startTime`, clamped to [0, duration].
    public func target(startTime: Double, metres: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        let start = startTime.isFinite ? min(max(startTime, 0), duration) : 0
        guard metres.isFinite else { return start }
        let travel = abs(metres) <= deadZone ? 0 : metres - (metres > 0 ? deadZone : -deadZone)
        return min(max(start + travel * secondsPerMetre(duration: duration), 0), duration)
    }

    /// The horizontal component of a drag, measured along the viewer's right
    /// as seen from where the drag began, so it means "right" whichever way
    /// the user faces. Vertical movement is ignored.
    public static func horizontalDistance(translation: SIMD3<Float>,
                                          startLocation: SIMD3<Float>,
                                          viewer: SIMD3<Float> = .zero) -> Float {
        var forward = startLocation - viewer
        forward.y = 0
        guard simd_length(forward) > 1e-4, translation.x.isFinite, translation.z.isFinite else {
            return translation.x.isFinite ? translation.x : 0
        }
        let right = simd_normalize(simd_cross(simd_normalize(forward), SIMD3<Float>(0, 1, 0)))
        return simd_dot(translation, right)
    }
}

/// Leading-edge throttle with an injectable clock.
public struct IPaVisionSeekThrottle: Sendable {
    public let interval: TimeInterval
    private var lastFire: TimeInterval?

    public init(interval: TimeInterval) { self.interval = interval }

    public mutating func shouldFire(at now: TimeInterval) -> Bool {
        if let lastFire, now - lastFire < interval { return false }
        lastFire = now
        return true
    }

    public mutating func reset() { lastFire = nil }
}

/// Drives one scrub at a time against the host's transport.
@MainActor
public final class IPaVisionScrubCoordinator {
    public enum State: Equatable, Sendable {
        case idle
        /// Dragging; `target` is where the drag currently points.
        case scrubbing(target: Double, duration: Double)
        /// Released; the exact seek to `target` is in flight.
        case settling(target: Double, duration: Double)
        /// A drag began on an item that can't be seeked.
        case unavailable(IPaVisionSeekableRange)
    }

    public private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    public var onStateChange: ((State) -> Void)?
    public var mapping: IPaVisionScrubMapping

    private weak var controller: (any IPaVisionPlaybackControlling)?
    private var throttle: IPaVisionSeekThrottle
    private let clock: () -> TimeInterval
    private var startTime: Double = 0
    private var wasPlaying = false
    private var lastIssuedTarget: Double?
    private var generation = 0

    public init(controller: any IPaVisionPlaybackControlling,
                mapping: IPaVisionScrubMapping = .init(),
                throttleInterval: TimeInterval = 0.15,
                clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.controller = controller
        self.mapping = mapping
        self.throttle = IPaVisionSeekThrottle(interval: throttleInterval)
        self.clock = clock
    }

    /// Starts a scrub. Returns false (and reports `.unavailable`) for live /
    /// unknown ranges; nothing is paused or seeked then.
    @discardableResult
    public func begin() -> Bool {
        guard let controller else { return false }
        generation &+= 1
        let range = controller.seekableRange
        guard let duration = range.duration else {
            state = .unavailable(range)
            return false
        }
        startTime = min(max(controller.currentTime.isFinite ? controller.currentTime : 0, 0), duration)
        // A drag that interrupts a previous release keeps that release's
        // original playing state.
        if case .settling = state {} else { wasPlaying = controller.isPlaying }
        if controller.isPlaying { controller.pause() }
        throttle.reset()
        lastIssuedTarget = nil
        state = .scrubbing(target: startTime, duration: duration)
        return true
    }

    /// Moves the target; issues a throttled fast seek. Returns that seek's task.
    @discardableResult
    public func update(horizontalMetres metres: Double) -> Task<Void, Never>? {
        guard case let .scrubbing(_, duration) = state, let controller else { return nil }
        let target = mapping.target(startTime: startTime, metres: metres, duration: duration)
        state = .scrubbing(target: target, duration: duration)
        if let last = lastIssuedTarget, abs(last - target) < 0.05 { return nil }
        guard throttle.shouldFire(at: clock()) else { return nil }
        lastIssuedTarget = target
        return Task { _ = await controller.seek(to: target, precision: .fast) }
    }

    /// Ends the scrub: one exact seek, then the playing state from `begin()`.
    @discardableResult
    public func end() -> Task<Void, Never>? {
        switch state {
        case .unavailable:
            state = .idle
            return nil
        case let .scrubbing(target, duration):
            return settle(at: target, duration: duration)
        case .idle, .settling:
            return nil
        }
    }

    /// Abandons the scrub: returns to where it started.
    @discardableResult
    public func cancel() -> Task<Void, Never>? {
        switch state {
        case .unavailable:
            state = .idle
            return nil
        case let .scrubbing(_, duration):
            return settle(at: startTime, duration: duration)
        case .idle, .settling:
            return nil
        }
    }

    private func settle(at target: Double, duration: Double) -> Task<Void, Never>? {
        guard let controller else { state = .idle; return nil }
        generation &+= 1
        let current = generation
        let resume = wasPlaying
        state = .settling(target: target, duration: duration)
        return Task { [weak self] in
            _ = await controller.seek(to: target, precision: .exact)
            guard let self, self.generation == current else { return }
            if resume { controller.play() }
            self.state = .idle
        }
    }
}
