//
//  IPaVRVideoProjection.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/1.
//

import SceneKit
import SpriteKit

class IPaVRVideoProjection:NSObject {
    func caculateSKScneeSize(_ videoScene:IPaVRVideoScene,camera: IPaVRVideoCamera) -> CGSize {
        return videoScene.videoSize
    }
    func attach(_ videoScene:IPaVRVideoScene,camera: IPaVRVideoCamera) {
        let skSceneSize = caculateSKScneeSize(videoScene,camera: camera)
        guard let videoSKNode = camera.spriteVideoNode else {
            return
        }
        camera.spriteKitScene.size = skSceneSize
        let transform = CGAffineTransform(scaleX: skSceneSize.width, y: skSceneSize.height)
        videoSKNode.size = camera.videoRect.size.applying(transform)
        let origin = camera.videoRect.origin.applying(transform)
        
        videoSKNode.position = origin.applying(CGAffineTransform(translationX: videoSKNode.size.width * 0.5, y: videoSKNode.size.height * 0.5))
        self.applyVideoZoom(videoScene,camera:camera)
        
        
    }
    func applyVideoZoom(_ videoScene: IPaVRVideoScene,camera:IPaVRVideoCamera) {
        guard let videoSKNode = camera.spriteVideoNode else {
            return
        }
        videoSKNode.size = videoSKNode.size.applying(CGAffineTransform(scaleX: videoScene.videoZoom, y: videoScene.videoZoom))
    }
    
    func detach(from videoScene:IPaVRVideoScene,camera:IPaVRVideoCamera) {
        
    }

//    func onPinch(_ sender:UIPinchGestureRecognizer, originZoom:CGFloat) {
//        self.videoZoom = max(1,min(2,sender.scale * originZoom))
//    }
}

