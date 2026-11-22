import XCTest
import SceneKit
import IPaAVPlayer
@testable import IPaVRKit

@MainActor
final class IPaVRKitTests: XCTestCase {
    func testVideoSceneBindsToTheGivenPlayer() {
        // An independent player, not `IPaAVPlayer.shared`.
        let player = IPaAVPlayer()
        let scene = IPaVRVideoScene(player)
        XCTAssertTrue(scene.avPlayer === player)
        let controls = scene.vrMenu.childNodes.compactMap { $0 as? IPaVRMenuPlayerControl }
        XCTAssertFalse(controls.isEmpty)
        for control in controls {
            XCTAssertTrue(control.avPlayer === player, "\(type(of: control)) is bound to another player")
            XCTAssertTrue(control.vrScene === scene)
        }
    }

    func testVideoSceneMenuAndPlayerAreReleased() {
        weak var weakScene: IPaVRVideoScene?
        weak var weakMenu: IPaVRMenuNode?
        weak var weakPlayer: IPaAVPlayer?
        // SceneKit autoreleases nodes it touches; drain them before checking.
        autoreleasepool {
            let player = IPaAVPlayer()
            let scene = IPaVRVideoScene(player)
            _ = scene.vrMenu
            weakScene = scene
            weakMenu = scene.vrMenu
            weakPlayer = player
        }
        drainSceneKit()
        XCTAssertNil(weakScene, "IPaVRVideoScene leaked (menu node / Combine retain cycle)")
        XCTAssertNil(weakMenu)
        XCTAssertNil(weakPlayer, "the scene kept its IPaAVPlayer alive")
    }

    func testViewAndSceneAreReleased() {
        weak var weakView: IPaVRView?
        weak var weakScene: IPaVRVideoScene?
        autoreleasepool {
            let view = IPaVRView(CGRect(x: 0, y: 0, width: 200, height: 100))
            let scene = IPaVRVideoScene(IPaAVPlayer())
            view.vrScene = scene
            XCTAssertTrue(scene.view === view)
            weakView = view
            weakScene = scene
        }
        drainSceneKit()
        XCTAssertNil(weakView, "IPaVRView leaked")
        XCTAssertNil(weakScene, "IPaVRVideoScene leaked through IPaVRView")
    }

    /// SceneKit keeps a node tree until its implicit transaction commits on the
    /// next run-loop pass; that is deferred release, not a leak.
    private func drainSceneKit() {
        SCNTransaction.flush()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
}
