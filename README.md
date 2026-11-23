# IPaVisionKit

visionOS immersive video rendering for an app that keeps its own player.
Independent of IPaVRKit (which stays iOS-only and is never linked on visionOS).

## Products

| Product | Platforms | Contents |
|---|---|---|
| `IPaVisionKitCore` | visionOS, iOS, macOS (host tests) | Foundation + simd only: `IPaVisionCorrection` (Codable, hard-clamped), metadata classification (`IPaVisionSourceMetadata`), `IPaVisionRenderPlan`, mesh / orientation math (`IPaVisionGeometry`), scrub mapping + `IPaVisionScrubCoordinator`, and the `IPaVisionPlaybackControlling` protocol |
| `IPaVisionKit` | visionOS (empty module elsewhere) | RealityKit renderer (`IPaVisionRenderer`), `IPaVisionImmersiveScene`, `IPaVisionImmersivePlayerView` for the host's `ImmersiveSpace`, indirect-pinch scrub gesture and HUD |

## Transport ownership

The package owns **no** playback state. It receives an `AVPlayer` only as a render
source (`VideoPlayerComponent(avPlayer:)` / `VideoMaterial(avPlayer:)`). Every play,
pause and seek goes through `IPaVisionPlaybackControlling`, implemented by the host
(KPPlayer forwards it to IPaAVPlayer 4).

## Rendering

- `IPaVisionCorrection.automatic` → **system** backend: `VideoPlayerComponent`. Tagged
  APMP 180/360 uses `desiredImmersiveViewingMode = .full`, everything else `.portal`
  on a 3 m screen 4 m ahead. The system reads the asset's tags itself (incl. stereo).
- Any manual correction → **custom mono** backend: mesh from `IPaVisionGeometry`
  (flat plane, 180° hemisphere or 360° sphere, inward-facing) with `VideoMaterial`.
  A packed stereo frame is split by `splitRatio`, `swapsEyes` picks the view, and that
  one view is shown to both eyes (`plan.stereoShownAsMono`).
- **custom stereo**: not implemented — `IPaVisionCustomStereoBackend.status` is
  `.unsupported`. See [docs/PHASE0.md](docs/PHASE0.md).

Controls: projection, stereo layout, eye swap, split ratio, field of view, zoom, yaw,
pitch, roll, horizon lock (drops roll), horizontal / vertical offset, convergence
(stored, clamped; only a stereo backend could apply it). `resetToAuto()` returns to
the system renderer.

## Scrubbing

`IPaVisionImmersivePlayerView` adds an invisible static-mesh collision shell (radius
2.5 m) around the viewer with `InputTargetComponent(allowedInputTypes: .indirect)`, so
an indirect pinch-and-drag anywhere is a horizontal scrub, independent of gaze target.
`IPaVisionScrubCoordinator`:

- refuses live / unknown ranges (`IPaVisionSeekableRange`) — nothing is paused or seeked,
  the HUD shows the host-supplied "unavailable" message;
- pauses during the drag, issues throttled (150 ms) `.fast` seeks, then one `.exact`
  seek on release, and resumes only if playback was running when the drag began;
- shows target time and progress in a billboarded attachment while scrubbing.

No system overlays are hidden, and the Digital Crown is not used.

## Tests

```sh
swift test                                   # Core, on the host
xcodebuild test -scheme IPaVisionKit-Package \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'   # Core + RealityKit
```
