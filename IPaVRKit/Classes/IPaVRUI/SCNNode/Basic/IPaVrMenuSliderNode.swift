//
//  IPaVrMenuSliderNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/17.
//


import SceneKit
import SpriteKit

public class IPaVrMenuSliderNode: SCNNode,IPaVRMenuItem {
    
    public var isHighlighted: Bool = false
    public var size:CGSize  {
        get {
            return CGSize(width: self.plane.width, height: self.plane.height)
        }
        set {
            self.plane.width = newValue.width
            self.plane.height = newValue.height
        }
    }
    lazy var plane:SCNPlane = {
        let plane = SCNPlane(width: 200, height: 8)
        plane.firstMaterial?.cullMode = .back
        plane.firstMaterial?.isDoubleSided = false
        return plane
    }()
    lazy var spriteScene:SKScene = {
        let scene = SKScene(size: self.size)
        scene.anchorPoint = CGPoint(x: 0, y: 0)
        scene.addChild(self.bgSpriteNode)
        scene.addChild(self.progressSpriteNode)
        return scene
    }()
    lazy var bgSpriteNode:SKShapeNode = {
        let node = SKShapeNode(rect: CGRect(origin: .zero, size: self.size))
        node.fillColor = backgroundColor
        node.strokeColor = backgroundColor
        node.zPosition = 0
        return node
    }()
    var backgroundColor = UIColor.lightGray {
        didSet {
            self.bgSpriteNode.fillColor = backgroundColor
        }
    }
    lazy var progressSpriteNode:SKShapeNode = {
        let node = SKShapeNode(rect: CGRect(x: 0, y: 0, width: self.size.width , height: self.size.height))
        node.fillColor = progressColor
        node.strokeColor = progressColor
        node.zPosition = 1
        node.xScale = CGFloat(self.value)
        return node
    }()
    var progressColor = UIColor.red {
        didSet {
            self.progressSpriteNode.fillColor = progressColor
        }
    }
    
    var _value:Float = 0.5
    var value:Float {
        get {
            return _value
        }
        set {
            self.setValue(CGFloat(newValue), animated: false)
        }
    }
 
    override init() {
        super.init()
        self.initialSetting()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initialSetting()
    }
    func initialSetting() {
        //size is provided by plane, so need to create plane first ,then create spriteScene
        self.plane.firstMaterial?.diffuse.contents = self.spriteScene
        self.geometry = self.plane
    }
    public func setValue(_ newValue:CGFloat,animated:Bool) {
        let action = SKAction.scaleX(to: newValue, y: 1, duration: animated ? 0.1 : 0)
        self.progressSpriteNode.run(action)
        self._value = Float(newValue)
    }
    public func onTap(_ result:SCNHitTestResult) {
        let zeroPointX = Float(-self.size.width * 0.5)
        self.value = (result.localCoordinates.x - zeroPointX) / Float(self.size.width)
    }
}
