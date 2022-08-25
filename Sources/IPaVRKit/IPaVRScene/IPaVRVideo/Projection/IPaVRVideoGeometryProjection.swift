//
//  IPaVRVideoGeometryProjection.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/2.
//

import SceneKit



class IPaVRVideoGeometryProjection: IPaVRVideoProjection {
    var videoNodeName:String {
        return "videoNode"
    }
    lazy var videoNode:SCNNode = {
        let node = SCNNode()
        node.geometry = self.createGeometry()
        return node
    }()
    func createGeometry() -> SCNGeometry {
        return SCNGeometry()
    }
    override func caculateSKScneeSize(_ videoScene:IPaVRVideoScene,camera: IPaVRVideoCamera)->CGSize {
        return videoScene.videoSize
    }
    override func attach(_ videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.attach(videoScene,camera: camera)
        
        if let videoNode = videoScene.scene.rootNode.childNode(withName: self.videoNodeName, recursively: false) {
            self.videoNode = videoNode
        }
        else {
            self.videoNode.geometry = self.createGeometry()
            self.videoNode.name = self.videoNodeName
            videoScene.scene.rootNode.addChildNode(self.videoNode)
            
        }

        self.videoNode.geometry?.firstMaterial?.diffuse.contents = nil
        self.videoNode.geometry?.firstMaterial?.diffuse.contents = camera.spriteKitScene
        self.videoNode.categoryBitMask = camera.camera.categoryBitMask
        
        
    }
    override func detach(from videoScene: IPaVRVideoScene, camera: IPaVRVideoCamera) {
        super.detach(from: videoScene, camera: camera)

      
//        sceneController.view.overlaySKScene = nil
        videoNode.geometry?.firstMaterial?.diffuse.contents = nil
        videoNode.removeFromParentNode()
    }
}
