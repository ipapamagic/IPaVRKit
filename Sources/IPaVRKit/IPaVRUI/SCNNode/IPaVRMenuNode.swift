//
//  IPaVRMenuNode.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/9.
//

import SceneKit
public class IPaVRMenuNode: SCNNode {
    static let vrMenuItemBitMask:Int = 0xF000000
    
    public var bgContent:Any? {
        get {
            return self.plane.firstMaterial?.diffuse.contents
        }
        set {
            self.plane.firstMaterial?.diffuse.contents = newValue
        }
    }
    public var size:CGSize = CGSize(width: 300, height: 200)
    @objc dynamic var currentHitTestResult:SCNHitTestResult? {
        didSet {
            let oldNode = oldValue?.node as? IPaVRMenuItem
            let newNode = currentHitTestResult?.node as? IPaVRMenuItem
            oldNode?.isHighlighted = false
            newNode?.isHighlighted = true
            
        }
    }
    public lazy var plane:SCNPlane = {
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        plane.firstMaterial?.cullMode = .back
        plane.cornerRadius = 20
        plane.firstMaterial?.isDoubleSided = false
        return plane
    }()
    public override init() {
        super.init()
        self.initialSetting()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initialSetting()
    }
    func initialSetting() {
        self.geometry = self.plane
    }
    public override func addChildNode(_ child: SCNNode) {
        super.addChildNode(child)
        if let item = child as? IPaVRMenuItem {
            item.categoryBitMask = IPaVRMenuNode.vrMenuItemBitMask
        }
    }
}
