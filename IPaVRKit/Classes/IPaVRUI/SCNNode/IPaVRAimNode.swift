//
//  IPaVRAimSKNode.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/8.
//

import SpriteKit
import IPaImageTool
import SceneKit
class IPaVRAimNode:SCNNode {
    var targetSelected:Bool = false {
        didSet {
            if targetSelected {
                let action = SKAction.resize(toWidth: self.highlightSize.width , height: self.highlightSize.height , duration: 0.1)
                
                self.skNode.run(action) {
                    self.skNode.run(SKAction.setTexture(self.hollowCircleTexture))
                }
                
            }
            else {
                let action = SKAction.resize(toWidth: self.size.width, height: self.size.height, duration: 0.1)
                self.skNode.run(action) {
                    self.skNode.run(SKAction.setTexture(self.circleTexture))
                }
            }
        }
    }
    
    lazy var circleTexture:SKTexture = {
        let imageSize = self.size
        let image = UIImage.createImage(imageSize) { context in
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: imageSize))
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(origin: .zero, size: imageSize))
        }
        return SKTexture(image: image!)
    }()
    lazy var hollowCircleTexture:SKTexture = {
        let imageSize = CGSize(width: self.highlightSize.width + 20 , height: self.highlightSize.height + 20)
        let image = UIImage.createImage(imageSize) { context in
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: imageSize))
            context.setStrokeColor(UIColor.white.cgColor)
            let width:CGFloat = self.size.width
            context.setLineWidth(width)
            let halfWidth = width * 0.5
            let path = UIBezierPath(ovalIn: CGRect(x: halfWidth, y: halfWidth, width: imageSize.width - width, height: imageSize.height - width))
            
            context.addPath(path.cgPath)
            context.strokePath()
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x:(imageSize.width  ) * 0.5 - self.size.width, y: (imageSize.height ) * 0.5  - self.size.height, width: self.size.width * 2, height: self.size.height * 2))
        }
        return SKTexture(image: image!)
    }()
    let size = CGSize(width: 2, height: 2)
    let highlightSize = CGSize(width: 35, height: 35)
    lazy var skNode:SKSpriteNode = {
        let node = SKSpriteNode(texture: self.circleTexture, size: self.size)
        return node
    }()
    override init() {
        super.init()
        self.geometry = self.plane
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public lazy var plane:SCNPlane = {
        let scene = SKScene()
        scene.size = CGSize(width: self.highlightSize.width, height: self.highlightSize.height)
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scene.backgroundColor = .clear
        scene.addChild(skNode)
        let plane = SCNPlane(width: scene.size.width, height: scene.size.height)
        plane.firstMaterial?.diffuse.contents = scene
        plane.firstMaterial?.cullMode = .back
        plane.firstMaterial?.isDoubleSided = false
        return plane
    }()
}
