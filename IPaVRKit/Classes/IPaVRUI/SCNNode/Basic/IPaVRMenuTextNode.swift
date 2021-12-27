//
//  IPaVRMenuTextNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/19.
//

import UIKit
import SceneKit

public class IPaVRMenuTextNode: SCNNode {
    public var text:String? {
        get {
            self.textGeometry.string as? String
        }
        set {
            self.textGeometry.string = newValue
            let (min, max) = self.boundingBox
            let dx = min.x + 0.5 * (max.x - min.x)
            let dy = min.y + 0.5 * (max.y - min.y)
            let dz = min.z + 0.5 * (max.z - min.z)
            self.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        }
    }
    public var textColor:UIColor {
        get {
            self.textGeometry.firstMaterial?.diffuse.contents as? UIColor ?? .white
        }
        set {
            self.textGeometry.firstMaterial?.diffuse.contents = newValue
        }
    }
    public var font:UIFont {
        get {
            return self.textGeometry.font
            
        }
        set {
            self.textGeometry.font = newValue
        }
    }
    lazy var textGeometry:SCNText = {
        let geometry = SCNText(string: "", extrusionDepth: 1)
        geometry.font = UIFont.systemFont(ofSize: 10)
        geometry.firstMaterial?.diffuse.contents = UIColor.white
        return geometry
    }()
    
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
    }
    func initialSetting() {
        
        self.geometry = self.textGeometry
    }
}
