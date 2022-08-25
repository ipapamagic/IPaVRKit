//
//  IPaVRVideoSphereProjection.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/2.
//

import SceneKit
import SpriteKit


class IPaVRVideoSphereProjection:IPaVRVideoGeometryProjection {
    let radius:CGFloat = 800
    override var videoNodeName:String {
        return "videoSphereNode"
    }
    open var is360 = true // false for 180 , true for 360
    override func createGeometry() -> SCNGeometry {
        let sphere = SCNSphere(radius: self.radius)
        sphere.firstMaterial?.cullMode = .front
        sphere.firstMaterial?.isDoubleSided = false
        return sphere
    }
    override func attach(_ videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.attach(videoScene,camera: camera)
        
        let skScene = camera.spriteKitScene
        let skSceneSize = videoScene.videoSize
        skScene.size = is360 ? skSceneSize : skSceneSize.applying(CGAffineTransform(scaleX: 2, y: 1))
        
        // Flip video upside down, so that it's shown in the right position
        var transform = SCNMatrix4MakeRotation(Float(Double.pi), 0.0, 0.0, 1.0)
        transform = SCNMatrix4Translate(transform, 1.0, 1.0, 0.0)

        videoNode.pivot = SCNMatrix4MakeRotation(Float(Double.pi/2), 0.0, -1.0, 0.0)
        videoNode.geometry?.firstMaterial?.diffuse.contentsTransform = transform
        videoNode.position = SCNVector3(x: 0, y: 0, z: 0)
        videoNode.eulerAngles = SCNVector3(0, self.is360 ? 0.5 * .pi : 0, 0)
        
        
    }
    
    
}
