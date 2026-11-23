# IPaVisionKit Phase-0 spike results (2026-11-23, Xcode 27.2 / visionOS 27.2 SDK, Mac mini, simulator only)

| Gate | Result | Evidence |
|---|---|---|
| Package builds; Core math tested | **Proved** | Originally in the standalone IPaVisionKit package. Since the merge into IPaVRKit (no macOS slice, so no host `swift test`): `xcodebuild test -scheme IPaVisionKit-visionOS` on the Apple Vision Pro simulator (visionOS 27.2): 68/68 (53 Core + 15 RealityKit); Core also 53/53 on an iOS simulator. See [VALIDATION.md](VALIDATION.md). |
| Auto path (`VideoPlayerComponent`) compiles and assembles | **Proved (compile + entity assembly)** | `IPaVisionKitTests.testAutomaticTaggedImmersiveUsesVideoPlayerComponentFull` / `testAutomaticFlatUsesPortalScreen`. What the headset shows for real APMP / MV-HEVC media needs hardware. |
| Custom mono (mesh + `VideoMaterial`) | **Proved (compile + entity assembly + geometry tests)** | `testManualCorrectionUsesMeshWithVideoMaterial`, `IPaVisionGeometryTests` (inward winding, UV regions, crop, orientation). |
| Own `ImmersiveSpace` opens | see KPPlayer `docs/visionos/IMMERSIVE.md` | proved in the app, not in this package |
| Indirect input-shell targeting: compile / API path | **Proved (API + components)** | `DragGesture().targetedToEntity(where: .has(IPaVisionInputShellComponent.self))`, `ShapeResource.generateStaticMesh`, `InputTargetComponent(allowedInputTypes: .indirect)`; `testInputShellIsIndirectOnlyCollisionWithoutModel`. **Not proved:** that a gaze ray starting *inside* the static-mesh shell hits its inward faces on device, and how the system routes a pinch when a window is also in view. Needs Vision Pro. |
| Custom stereo (Camera Index Switch) | **Not proved → unsupported stub** | The visionOS 27.2 RealityKit Swift interface has no camera-index / per-eye API; the Camera Index Switch exists only as a Reality Composer Pro ShaderGraph node, and the simulator renders a single view, so per-eye output can't be observed here. `IPaVisionCustomStereoBackend.status == .unsupported`; stereo corrections render mono. No stereo claim is made. |
| Must `AVPlayerVideoOutput` be exclusive? | **Not proved — treated as exclusive** | `AVPlayer.videoOutput` (AVPlayer.h, visionOS 1.1+) documents only that setting an output with a current item may re-select data channels. Neither AVFoundation nor RealityKit headers say whether it may coexist with `VideoMaterial` / `VideoPlayerComponent` on the same player. Until proved on hardware a custom stereo backend must assume exclusivity (one consumer per `AVPlayer`), which is why it stays disabled. |

## Hardware-only checks still open

1. Real 180/360 APMP and MV-HEVC media in `VideoPlayerComponent` `.full` / `.portal`.
2. Custom mono orientation (UV v-flip convention, yaw/pitch/roll signs) by eye.
3. Pinch from inside the static-mesh shell; interaction with the player window in view.
4. `IPaVisionImmersiveScene.eyeHeight` (1.5 m fixed) vs the actual head height.
5. The same `AVPlayer` drawn by `AVPlayerViewController` (window) and the immersive
   entity at once.
6. Camera Index Switch + `AVPlayerVideoOutput` coexistence before any custom stereo.

## Demo-safety fixes (2026-11-23)

- MV-HEVC + manual correction → custom mono now reports `.multiviewShownAsMono` /
  `isMonoDowngrade`, and the immersive view shows a persistent mono badge.
  Convergence alone, and eye swap / split ratio on a non-packed layout, never leave
  the system renderer.
- Scrub cleanup on system-cancelled gestures and on view disappearance (tests:
  `IPaVisionScrubTests` cancellation group, `IPaVisionKitTests` scrub cleanup group).
  Not proved on device: that visionOS actually resets `@GestureState` for an indirect
  pinch the system cancels (e.g. a system overlay taking the hand).
