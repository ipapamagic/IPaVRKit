//
//  IPaVRMenuButton.swift
//  IPaVRVideoPlayer
//
//  Created by IPa Chen on 2021/12/9.
//

import SceneKit
import SpriteKit
public class IPaVRMenuButtonNode: SCNNode,IPaVRMenuItem {
    public weak var actionTarget:NSObject?
    public var actionSelector:Selector?
    @objc dynamic public var isHighlighted: Bool = false {
        didSet {
            let scale = isHighlighted ? 1.2 : 1
            let action = SCNAction.scale(to: scale, duration: 0.1)
            self.removeAllActions()
            self.runAction(action)
        }
    }
    @objc dynamic public var image:Any? {
        didSet {
            let plane = (self.geometry as! SCNPlane)
            plane.firstMaterial?.diffuse.contents = nil
            plane.firstMaterial?.diffuse.contents = image
        }
    }
    public var size:CGSize = CGSize(width: 30, height: 30)
    override public init() {
        super.init()
        self.initialSetting()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initialSetting()
    }
    convenience public init(_ target:NSObject,action:Selector){
        self.init()
        self.actionTarget = target
        self.actionSelector = action
    }
    func initialSetting() {
        let plane = SCNPlane(width: self.size.width, height: self.size.height)
        plane.firstMaterial?.diffuse.contents = self.image
        plane.firstMaterial?.cullMode = .back
        plane.firstMaterial?.isDoubleSided = false
        self.geometry = plane
    }
    public func onTap(_ result:SCNHitTestResult) {
        guard let target = actionTarget ,let selector = actionSelector else {
            return
        }
        target.perform(selector, with: self)
    }
}
public class IPaVRMenuSKButtonNode:IPaVRMenuButtonNode {
    public lazy var skScene:SKScene = {
        let scene = SKScene()
        let transform = CGAffineTransform(scaleX: 3, y: 3)
        scene.size = self.size.applying(transform)
        scene.backgroundColor = .clear
        return scene
    }()
    public override var size: CGSize {
        didSet {
            self.skScene.size = self.size
        }
    }
    override func initialSetting() {
        super.initialSetting()
        self.image = skScene
    }
    
}
public class IPaVRMenuSimpleButtonNode:IPaVRMenuButtonNode {
    var defaultImage:UIImage? {
        get {
            return nil
        }
    }
    override func initialSetting() {
        super.initialSetting()
        self.image = self.defaultImage
        self.actionTarget = self
        self.actionSelector = #selector(self.buttonAction(_:))
    }

    @objc public func buttonAction(_ sender:Any) {
        
    }
}
