//
//  IPaVRVideoCamera.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/13.
//

import SceneKit
import SpriteKit
import Combine
class IPaVRVideoCamera: NSObject {
    var videoRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var camera:SCNNode = {
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        camera.zFar = 1000
        camera.zNear = 1
        cameraNode.position = SCNVector3(x:0, y: 0, z: 0)
        return cameraNode
    }()
    var viewBoundsAnyCancellable:AnyCancellable?
    weak var scene:IPaVRVideoScene?
    weak var view:SCNView? {
        didSet {
            if let view = view,let scene = scene {
                self.viewBoundsAnyCancellable = view.publisher(for: \.bounds,options: [.new]).sink(receiveValue: { bounds in
                    scene.currentProjection.attach(scene, camera: self)
                })
            }
            else {
                self.viewBoundsAnyCancellable = nil
            }
            
            self.syncViewOverlay()
        }
    }
    var overlaySKScene:SKScene? {
        didSet {
            self.syncViewOverlay()
        }
    }
    lazy var spriteKitScene:SKScene = {
        let scene = SKScene()
        scene.scaleMode = .aspectFill
        return scene
    }()
    var spriteVideoNode:SKVideoNode? {
        didSet {
            if let oldValue = oldValue {
                oldValue.removeFromParent()
            }
            guard let videoNode = spriteVideoNode else {
                return
            }
            spriteKitScene.addChild(videoNode)
            videoNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
    }

    
    func syncViewOverlay() {
        guard let view = view else {
            return
        }
        view.overlaySKScene = overlaySKScene
        self.overlaySKScene?.size = view.bounds.size
        
    }
    
}
