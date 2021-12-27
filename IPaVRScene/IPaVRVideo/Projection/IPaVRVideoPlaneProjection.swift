//
//  IPaVRVideoPlaneProjection.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/2.
//

import SceneKit
import SpriteKit

class IPaVRVideoPlaneProjection: IPaVRVideoGeometryProjection {
    override var videoNodeName:String {
        return "planeNode"
    }
    var planeSize = CGSize(width: 100, height: 100)
    let distance:Float = -500
    let maxPlaneConstant:CGFloat = 400
    override func createGeometry() -> SCNGeometry {
        let plane = SCNPlane(width: planeSize.width, height: planeSize.height)
        plane.firstMaterial?.cullMode = .front
        plane.firstMaterial?.isDoubleSided = false
        return plane
    }
    override func attach(_ videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.attach(videoScene,camera: camera)
       
        // Flip video upside down, so that it's shown in the right position
        videoNode.position = SCNVector3(x: 0, y: 0, z: distance)
        videoNode.eulerAngles.x = .pi        
    }
    override func applyVideoZoom(_ videoScene: IPaVRVideoScene,camera:IPaVRVideoCamera) {
        
      
        let videoSize = videoScene.videoSize
        if videoSize.width > videoSize.height {
            self.planeSize.width = maxPlaneConstant
            self.planeSize.height = maxPlaneConstant * videoSize.height / videoSize.width
        }
        else {
            self.planeSize.height = maxPlaneConstant
            self.planeSize.width = maxPlaneConstant * videoSize.width / videoSize.height
        }
        self.planeSize = self.planeSize.applying(CGAffineTransform(scaleX: videoScene.videoZoom, y: videoScene.videoZoom))
        let plane = (videoNode.geometry as! SCNPlane)
        plane.width = self.planeSize.width
        plane.height = self.planeSize.height
        
        videoNode.geometry = plane
    }
    
}

