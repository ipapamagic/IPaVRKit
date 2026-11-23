//
//  IPaVisionImmersivePlayerView.swift
//  IPaVisionKit
//
//  Content for the host app's own `ImmersiveSpace`. It draws `player` (a
//  source only) and turns an indirect pinch-and-drag anywhere around the
//  viewer into scrubbing through `controller`, the host's transport.
//
//  It hides no system UI and does not use the Digital Crown.
//

#if os(visionOS)
import AVFoundation
import RealityKit
import SwiftUI
import IPaVisionKitCore

public struct IPaVisionImmersivePlayerView: View {
    private let player: AVPlayer
    private let controller: any IPaVisionPlaybackControlling
    private let metadata: IPaVisionSourceMetadata
    private let correction: IPaVisionCorrection
    private let unavailableMessage: String
    private let monoDowngradeMessage: String
    @State private var scene = IPaVisionImmersiveScene()
    /// True while the drag is active; SwiftUI resets it when the gesture ends
    /// *or* is cancelled, which `onEnded` alone does not report.
    @GestureState private var isScrubGestureActive = false

    /// - Parameters:
    ///   - player: what to draw. Never played, paused or seeked by this view.
    ///   - controller: the host's transport; receives every scrub seek.
    ///   - unavailableMessage: shown when a pinch lands on a live / unknown item.
    ///   - monoDowngradeMessage: shown in the space for as long as a stereo
    ///     source is drawn mono (`IPaVisionRenderPlan.isMonoDowngrade`).
    public init(player: AVPlayer,
                controller: any IPaVisionPlaybackControlling,
                metadata: IPaVisionSourceMetadata,
                correction: IPaVisionCorrection,
                unavailableMessage: String = "Seeking is unavailable for this stream",
                monoDowngradeMessage: String = "Stereo video shown in mono: both eyes see the same view") {
        self.player = player
        self.controller = controller
        self.metadata = metadata
        self.correction = correction
        self.unavailableMessage = unavailableMessage
        self.monoDowngradeMessage = monoDowngradeMessage
    }

    public var body: some View {
        RealityView { content, attachments in
            content.add(scene.root)
            if let hud = attachments.entity(for: HUDID.scrub) {
                scene.attachHUD(hud)
            }
            if let notice = attachments.entity(for: HUDID.mono) {
                scene.attachMonoNotice(notice)
            }
            scene.apply(player: player, metadata: metadata, correction: correction)
        } attachments: {
            Attachment(id: HUDID.scrub) {
                IPaVisionScrubHUD(state: scene.scrubState,
                                  showsUnavailable: scene.showsScrubUnavailable,
                                  unavailableMessage: unavailableMessage)
            }
            Attachment(id: HUDID.mono) {
                IPaVisionMonoNotice(message: monoDowngradeMessage)
            }
        }
        .gesture(scrubGesture)
        .onChange(of: isScrubGestureActive) { wasActive, isActive in
            if wasActive, !isActive { scene.scrubGestureReset() }
        }
        .onDisappear { scene.tearDown() }
        .task {
            scene.bind(controller: controller)
            await scene.installInputShell()
        }
        .onChange(of: correction) { _, newValue in
            scene.apply(player: player, metadata: metadata, correction: newValue)
        }
        .onChange(of: metadata) { _, newValue in
            scene.apply(player: player, metadata: newValue, correction: correction)
        }
    }

    private enum HUDID {
        static let scrub = "IPaVision.scrubHUD"
        static let mono = "IPaVision.monoNotice"
    }

    /// Only the input shell is a target, and it only accepts indirect input,
    /// so this is a gaze-independent "pinch anywhere and drag sideways".
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToEntity(where: .has(IPaVisionInputShellComponent.self))
            .updating($isScrubGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let start = value.convert(value.startLocation3D, from: .local, to: .scene)
                let translation = value.convert(value.translation3D, from: .local, to: .scene)
                scene.scrubChanged(startLocation: start, translation: translation)
            }
            .onEnded { _ in scene.scrubEnded() }
    }
}

/// Persistent badge while a stereo source is shown mono.
struct IPaVisionMonoNotice: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "eye.trianglebadge.exclamationmark")
            .font(.callout)
            .padding(14)
            .glassBackgroundEffect()
    }
}

/// Target time and progress while scrubbing.
struct IPaVisionScrubHUD: View {
    let state: IPaVisionScrubCoordinator.State
    let showsUnavailable: Bool
    let unavailableMessage: String

    var body: some View {
        Group {
            switch state {
            case let .scrubbing(target, duration), let .settling(target, duration):
                VStack(spacing: 10) {
                    Text("\(IPaVisionTimeFormat.string(target)) / \(IPaVisionTimeFormat.string(duration))")
                        .font(.title2.monospacedDigit())
                    ProgressView(value: min(max(target, 0), duration), total: max(duration, 0.001))
                        .frame(width: 360)
                }
            case .unavailable, .idle:
                if showsUnavailable || state != .idle {
                    Label(unavailableMessage, systemImage: "dot.radiowaves.left.and.right")
                        .font(.title3)
                }
            }
        }
        .padding(20)
        .glassBackgroundEffect()
    }
}

enum IPaVisionTimeFormat {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
#endif
