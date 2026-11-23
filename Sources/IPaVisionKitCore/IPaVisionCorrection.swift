//
//  IPaVisionCorrection.swift
//  IPaVisionKitCore
//
//  The user's manual geometry correction for one video. `.automatic` means
//  "trust the file": nothing is overridden and the system renderer plays the
//  asset as tagged. Any other value is rendered by the custom renderer.
//
//  Every numeric control is hard-clamped: on init, on every `clamped()` call
//  and when decoding, so a corrupt or hand-edited stored value can never put a
//  non-finite or out-of-range number into the renderer.
//

import Foundation

public struct IPaVisionCorrection: Codable, Equatable, Hashable, Sendable {
    /// How the picture is mapped around the viewer.
    public enum Projection: String, Codable, CaseIterable, Sendable {
        /// Use the file's projection tag (rectilinear when untagged).
        case auto
        /// A flat screen in front of the viewer.
        case flat
        /// Full-sphere equirectangular.
        case equirectangular360
        /// Front-hemisphere (half) equirectangular.
        case equirectangular180
    }

    /// How the two eyes are packed into one frame.
    public enum StereoLayout: String, Codable, CaseIterable, Sendable {
        /// Use the file's view-packing tag (mono when untagged).
        case auto
        case mono
        /// Left | right.
        case sideBySide
        /// Top / bottom.
        case overUnder
    }

    /// Valid ranges. Degrees for angles, fractions of the eye image for offsets.
    public enum Limits {
        public static let splitRatio: ClosedRange<Double> = 0.25...0.75
        /// Horizontal angular size the picture covers.
        public static let fieldOfView: ClosedRange<Double> = 20...360
        public static let zoom: ClosedRange<Double> = 0.5...3
        public static let yaw: ClosedRange<Double> = -180...180
        public static let pitch: ClosedRange<Double> = -90...90
        public static let roll: ClosedRange<Double> = -180...180
        public static let offset: ClosedRange<Double> = -0.5...0.5
        /// Horizontal per-eye convergence shift. Only a stereo backend can
        /// apply it; the mono renderer stores it but cannot show it.
        public static let convergence: ClosedRange<Double> = -5...5
    }

    public static let currentVersion = 1

    public var projection: Projection
    public var stereoLayout: StereoLayout
    /// Treat the second packed view as the left eye.
    public var swapsEyes: Bool
    /// Where the packed views are split: the first view's share of the frame.
    public var splitRatio: Double
    /// Horizontal angular size in degrees; nil = the projection's default.
    public var fieldOfView: Double?
    public var zoom: Double
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    /// Keeps the picture's horizon level: roll is ignored while on.
    public var horizonLock: Bool
    public var horizontalOffset: Double
    public var verticalOffset: Double
    public var convergence: Double

    public init(projection: Projection = .auto,
                stereoLayout: StereoLayout = .auto,
                swapsEyes: Bool = false,
                splitRatio: Double = 0.5,
                fieldOfView: Double? = nil,
                zoom: Double = 1,
                yaw: Double = 0,
                pitch: Double = 0,
                roll: Double = 0,
                horizonLock: Bool = false,
                horizontalOffset: Double = 0,
                verticalOffset: Double = 0,
                convergence: Double = 0) {
        self.projection = projection
        self.stereoLayout = stereoLayout
        self.swapsEyes = swapsEyes
        self.splitRatio = splitRatio
        self.fieldOfView = fieldOfView
        self.zoom = zoom
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.horizonLock = horizonLock
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.convergence = convergence
        self = clamped()
    }

    /// Trust the file; the reset target.
    public static let automatic = IPaVisionCorrection()

    /// True when nothing is overridden, so the system renderer is used.
    public var isAutomatic: Bool { clamped() == .automatic }

    /// Back to `.automatic`.
    public mutating func resetToAuto() { self = .automatic }

    /// Every value inside its range; non-finite numbers fall back to defaults.
    public func clamped() -> IPaVisionCorrection {
        var copy = self
        copy.splitRatio = Self.clamp(splitRatio, Limits.splitRatio, fallback: 0.5)
        copy.fieldOfView = fieldOfView.map { Self.clamp($0, Limits.fieldOfView, fallback: 90) }
        copy.zoom = Self.clamp(zoom, Limits.zoom, fallback: 1)
        copy.yaw = Self.clamp(yaw, Limits.yaw, fallback: 0)
        copy.pitch = Self.clamp(pitch, Limits.pitch, fallback: 0)
        copy.roll = Self.clamp(roll, Limits.roll, fallback: 0)
        copy.horizontalOffset = Self.clamp(horizontalOffset, Limits.offset, fallback: 0)
        copy.verticalOffset = Self.clamp(verticalOffset, Limits.offset, fallback: 0)
        copy.convergence = Self.clamp(convergence, Limits.convergence, fallback: 0)
        return copy
    }

    /// The roll actually applied (0 under horizon lock).
    public var effectiveRoll: Double { horizonLock ? 0 : roll }

    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: Codable (tolerant + clamping)

    private enum CodingKeys: String, CodingKey {
        case version, projection, stereoLayout, swapsEyes, splitRatio, fieldOfView, zoom
        case yaw, pitch, roll, horizonLock, horizontalOffset, verticalOffset, convergence
    }

    /// Missing keys take their defaults and unknown enum values fall back to
    /// `.auto`, so an older or newer stored record still decodes, clamped.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys, _ fallback: Double) -> Double {
            (try? c.decodeIfPresent(Double.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        let projection = (try? c.decodeIfPresent(String.self, forKey: .projection)).flatMap { $0 }
            .flatMap(Projection.init(rawValue:)) ?? .auto
        let layout = (try? c.decodeIfPresent(String.self, forKey: .stereoLayout)).flatMap { $0 }
            .flatMap(StereoLayout.init(rawValue:)) ?? .auto
        self.init(projection: projection,
                  stereoLayout: layout,
                  swapsEyes: (try? c.decodeIfPresent(Bool.self, forKey: .swapsEyes)).flatMap { $0 } ?? false,
                  splitRatio: number(.splitRatio, 0.5),
                  fieldOfView: (try? c.decodeIfPresent(Double.self, forKey: .fieldOfView)).flatMap { $0 },
                  zoom: number(.zoom, 1),
                  yaw: number(.yaw, 0),
                  pitch: number(.pitch, 0),
                  roll: number(.roll, 0),
                  horizonLock: (try? c.decodeIfPresent(Bool.self, forKey: .horizonLock)).flatMap { $0 } ?? false,
                  horizontalOffset: number(.horizontalOffset, 0),
                  verticalOffset: number(.verticalOffset, 0),
                  convergence: number(.convergence, 0))
    }

    public func encode(to encoder: any Encoder) throws {
        let value = clamped()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentVersion, forKey: .version)
        try c.encode(value.projection.rawValue, forKey: .projection)
        try c.encode(value.stereoLayout.rawValue, forKey: .stereoLayout)
        try c.encode(value.swapsEyes, forKey: .swapsEyes)
        try c.encode(value.splitRatio, forKey: .splitRatio)
        try c.encodeIfPresent(value.fieldOfView, forKey: .fieldOfView)
        try c.encode(value.zoom, forKey: .zoom)
        try c.encode(value.yaw, forKey: .yaw)
        try c.encode(value.pitch, forKey: .pitch)
        try c.encode(value.roll, forKey: .roll)
        try c.encode(value.horizonLock, forKey: .horizonLock)
        try c.encode(value.horizontalOffset, forKey: .horizontalOffset)
        try c.encode(value.verticalOffset, forKey: .verticalOffset)
        try c.encode(value.convergence, forKey: .convergence)
    }
}
