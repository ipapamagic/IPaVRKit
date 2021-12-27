//
//  IPaVRVideoFullScreenProjection.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/2.
//

import SceneKit
import SpriteKit

class IPaVRVideoFullScreenProjection: IPaVRVideoProjection {
    override func caculateSKScneeSize(_ videoScene:IPaVRVideoScene,camera: IPaVRVideoCamera)->CGSize {
        let viewSize = camera.view?.bounds.size ?? CGSize(width: 1, height: 1)
        return viewSize
//        let videoSize = videoScene.videoSize
//
//        let videoRatio = videoSize.width / videoSize.height
//        var screenSize = viewSize
//        if videoRatio > (viewSize.width / viewSize.height) {
//            screenSize.height = screenSize.width / videoRatio
//        }
//        else {
//            screenSize.width = screenSize.height * videoRatio
//        }
//        return screenSize
    }
    override func attach(_ videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.attach(videoScene,camera: camera)
        camera.overlaySKScene = camera.spriteKitScene
    }
    override func detach(from videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.detach(from: videoScene, camera: camera)

        camera.spriteKitScene.removeFromParent()
        camera.overlaySKScene = nil
    }
}
