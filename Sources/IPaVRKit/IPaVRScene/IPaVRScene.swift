//
//  IPaVRScene.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/11.
//

import SceneKit
import SpriteKit
import CoreMotion
public class IPaVRScene:NSObject {
    static public override func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "view" {
            return Set(["_view"])
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }
    var _view:IPaVRView?
    @objc public dynamic var view:IPaVRView? {
        return _view
    }
    lazy public var scene = SCNScene()
    public var eyesInterval:Float {
        get {
            return self.rightCameraNode.position.x * 2
        }
        set {
            let interval = newValue * 0.5
            self.leftCameraNode.position = SCNVector3(-interval, 0, 0)
            self.rightCameraNode.position = SCNVector3(interval, 0, 0)
        }
    }
    public var currentEularAngle:SCNVector3 {
        get {
            return self.cameraRootNode.eulerAngles
        }
        set {
            self.cameraRootNode.eulerAngles = newValue
        }
    }
    public var leftCameraNode:SCNNode {
        get {
            return SCNNode()
        }
    }
    public var rightCameraNode:SCNNode {
        get {
            return SCNNode()
        }
    }
    lazy public var cameraRootNode:SCNNode = {
        let node = SCNNode()
        node.addChildNode(leftCameraNode)
        node.addChildNode(rightCameraNode)
        self.scene.rootNode.addChildNode(node)
        return node
    }()
    public func onTap() -> Bool {
        return false
    }
    public func onSetup(_ leftView:SCNView,rightView:SCNView) {
        
    }
    public func renderer(_ view: IPaVRView, updateAtTime time: TimeInterval) {
        
    }
    func faceToCenter() {
        self.currentEularAngle = SCNVector3(0, 0, 0)
    }
}
