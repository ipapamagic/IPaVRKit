# Validation: IPaVisionKit merged into IPaVRKit

Date: 2026-11-23 · Mac mini: Xcode 27.2, iOS 27 / visionOS 27.2 simulators

`IPaVisionKitCore` and `IPaVisionKit` were developed as the separate local
package `IPaVisionKit` (`main` @ `5051f60`) and merged into IPaVRKit's
`visionos-module` branch (from `ipaavplayer-4`) with
`git merge --allow-unrelated-histories`, keeping their history.

## Supported routes

The package declares iOS 15 and visionOS 26 only. `IPaVRKit` needs UIKit,
SceneKit and CoreMotion, so **host `swift test` / `swift build` on macOS is not a
supported route** (the standalone IPaVisionKit's macOS test slice is gone). Use
`xcodebuild` on simulators:

| Route | Command | Covers |
|---|---|---|
| iOS | `xcodebuild test -scheme IPaVRKit-Package -destination 'platform=iOS Simulator,…'` | `IPaVRKitTests`, `IPaVisionKitCoreTests` on iOS; `IPaVisionKit` compiles to an empty module |
| visionOS | `xcodebuild test -scheme IPaVisionKit-visionOS -destination 'platform=visionOS Simulator,name=Apple Vision Pro'` | `IPaVisionKitCoreTests` + `IPaVisionKitTests` (RealityKit). Builds only the two visionOS modules: no IPaVRKit / IPaAVPlayer / IPaImageTool for visionOS |

`IPaVisionKit-visionOS` is a shared scheme tracked in
`.swiftpm/xcode/xcshareddata/xcschemes/` (`.gitignore` ignores the rest of `.swiftpm`).
With several products, Xcode's auto-generated `IPaVRKit` scheme has no test
action; use `IPaVRKit-Package` for the iOS tests.

## IPaAVPlayer 4.0.0 is not tagged yet

The manifest asks for IPaAVPlayer `from: "4.0.0"`, which cannot resolve before the
tag exists, and SwiftPM resolves the whole graph even for the visionOS scheme.
Validation therefore runs on a clean export of the committed tree
(`git ls-files` / `git archive`) in which that one line is replaced with an exact
commit (same procedure as KPPlayer `docs/integration/VALIDATION.md`):

```swift
.package(url: "file:///Volumes/OpenClawData/Projects/IPaAVPlayer", revision: "1cc89f88801dd02d028b91cc36ada1ecfb4be7f6"),
```

Apps that pin IPaAVPlayer themselves (KPPlayer) override it at the root and need
no edit.

## Results (IPaAVPlayer @ 1cc89f8)

| Run | Result |
|---|---|
| `xcodebuild test -scheme IPaVRKit-Package`, iOS 27 simulator | TEST SUCCEEDED: IPaVRKitTests 3/3, IPaVisionKitCoreTests 53/53 |
| `xcodebuild test -scheme IPaVisionKit-visionOS`, Apple Vision Pro simulator (visionOS 27.2) | TEST SUCCEEDED: IPaVisionKitCoreTests 53/53, IPaVisionKitTests 15/15 |
| visionOS build products | only `IPaVisionKit` / `IPaVisionKitCore` (+ tests); no `IPaVRKit`, `IPaAVPlayer`, `IPaImageTool` |

## Not validated: needs real hardware

See [PHASE0.md](PHASE0.md) "Hardware-only checks still open" (APMP / MV-HEVC in
`VideoPlayerComponent`, custom mono orientation by eye, pinch from inside the
input shell, eye height, shared `AVPlayer` window + immersive, custom stereo), and
on iPhone the Cardboard / CoreMotion checks in KPPlayer's validation notes.
