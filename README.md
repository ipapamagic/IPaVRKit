# IPaVRKit

IPaVRKit is distributed as a Swift Package with three products:

| Product | Platforms | Contents |
|---|---|---|
| `IPaVRKit` | iOS 15+ | Cardboard / SceneKit / CoreMotion VR video player (`IPaVRView`, `IPaVRScene`, in-scene menu). Unchanged public API. Swift 5 language mode. |
| `IPaVisionKitCore` | iOS 15+, visionOS 26+ | Foundation + simd only: corrections, metadata classification, render plan, mesh / orientation math, scrub mapping. Swift 6 language mode. |
| `IPaVisionKit` | visionOS 26+ (empty module elsewhere) | RealityKit immersive renderer for Apple Vision Pro. Swift 6 language mode. |

An app links `IPaVRKit` on iOS only and `IPaVisionKit` on visionOS only (Xcode
platform filters); `IPaVisionKitCore` can link on both. `IPaVRKit` and its
dependencies (IPaAVPlayer, IPaImageTool) are never needed on visionOS, and the
visionOS renderer has no dependency on them.

## Installation

Add this repository in Xcode through **File > Add Package Dependencies**:

```text
https://github.com/ipapamagic/IPaVRKit.git
```

For in-progress app migrations, pin the package to the latest commit until a
version tag is cut.

## IPaVRKit (iOS)

SceneKit-based 360° / 180° / flat video player with Cardboard split view, head
tracking and an in-scene gaze menu, driven by IPaAVPlayer.

## IPaVisionKit (visionOS)

visionOS immersive video rendering for an app that keeps its own player. It was
developed as the separate `IPaVisionKit` package and merged here with its history.

### Products

| Product | Platforms | Contents |
|---|---|---|
| `IPaVisionKitCore` | iOS 15+, visionOS 26+ | Foundation + simd only: `IPaVisionCorrection` (Codable, hard-clamped), metadata classification (`IPaVisionSourceMetadata`), `IPaVisionRenderPlan`, mesh / orientation math (`IPaVisionGeometry`), scrub mapping + `IPaVisionScrubCoordinator`, and the `IPaVisionPlaybackControlling` protocol |
| `IPaVisionKit` | visionOS (empty module elsewhere) | RealityKit renderer (`IPaVisionRenderer`), `IPaVisionImmersiveScene`, `IPaVisionImmersivePlayerView` for the host's `ImmersiveSpace`, indirect-pinch scrub gesture and HUD |

### Transport ownership

The package owns **no** playback state. It receives an `AVPlayer` only as a render
source (`VideoPlayerComponent(avPlayer:)` / `VideoMaterial(avPlayer:)`). Every play,
pause and seek goes through `IPaVisionPlaybackControlling`, implemented by the host
(KPPlayer forwards it to IPaAVPlayer 4).

### Rendering

- `IPaVisionCorrection.automatic` → **system** backend: `VideoPlayerComponent`. Tagged
  APMP 180/360 uses `desiredImmersiveViewingMode = .full`, everything else `.portal`
  on a 3 m screen 4 m ahead. The system reads the asset's tags itself (incl. stereo).
- Controls the plan cannot apply are dropped before choosing a backend: convergence
  (needs a per-eye renderer) and, unless the layout is frame-packed, eye swap / split
  ratio. A correction made only of those keeps the system renderer
  (`.convergenceIgnored` / `.packingControlsIgnored`), so it never silently turns a
  stereo or MV-HEVC source mono. `plan.correction` is what is actually rendered.
- Any other manual correction → **custom mono** backend: mesh from `IPaVisionGeometry`
  (flat plane, 180° hemisphere or 360° sphere, inward-facing) with `VideoMaterial`.
  A packed stereo frame is split by `splitRatio`, `swapsEyes` picks the view, and that
  one view is shown to both eyes. An MV-HEVC source also gets only its primary view
  (`.multiviewShownAsMono`). Either way `plan.isMonoDowngrade` is true and
  `IPaVisionImmersivePlayerView` shows `monoDowngradeMessage` in the space for as long
  as it lasts; hosts should say so in their own UI too.
- **custom stereo**: not implemented — `IPaVisionCustomStereoBackend.status` is
  `.unsupported`. See [docs/PHASE0.md](docs/visionOS/PHASE0.md).

Controls: projection, stereo layout, eye swap, split ratio, field of view, zoom, yaw,
pitch, roll, horizon lock (drops roll), horizontal / vertical offset, convergence
(stored, clamped; only a stereo backend could apply it). `resetToAuto()` returns to
the system renderer.

### Scrubbing

`IPaVisionImmersivePlayerView` adds an invisible static-mesh collision shell (radius
2.5 m) around the viewer with `InputTargetComponent(allowedInputTypes: .indirect)`, so
an indirect pinch-and-drag anywhere is a horizontal scrub, independent of gaze target.
`IPaVisionScrubCoordinator`:

- refuses live / unknown ranges (`IPaVisionSeekableRange`) — nothing is paused or seeked,
  the HUD shows the host-supplied "unavailable" message;
- pauses during the drag, issues throttled (150 ms) `.fast` seeks, then one `.exact`
  seek on release, and resumes only if playback was running when the drag began;
- shows target time and progress in a billboarded attachment while scrubbing.
- a gesture the system cancels (no `onEnded`) is detected through `@GestureState`
  reset and cancelled (`gestureDidReset()`: back to the start position, playing state
  restored); the view's `onDisappear` tears down an unfinished scrub the same way; a
  release that is still settling resumes playback even if its view is already gone.

No system overlays are hidden, and the Digital Crown is not used.

## Validation

There is no macOS slice (the iOS target needs UIKit / SceneKit / CoreMotion), so
host `swift test` is **not** a supported route. Use simulators:

```sh
# iOS: Cardboard / SceneKit player
xcodebuild test -scheme IPaVRKit-Package \
  -destination 'platform=iOS Simulator,name=<iPhone>'   # IPaVRKit + Core tests

# visionOS: Core + RealityKit renderer (shared scheme in .swiftpm/xcode/xcshareddata)
xcodebuild test -scheme IPaVisionKit-visionOS \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
```

Until IPaAVPlayer 4.0.0 is tagged, `from: "4.0.0"` cannot resolve on its own;
see [docs/visionOS/VALIDATION.md](docs/visionOS/VALIDATION.md) for the
commit-pinned validation procedure and the latest results.

## Author

IPa Chen, ipapamagic@gmail.com

## License

IPaVRKit is available under the MIT license. See the LICENSE file for more info.
