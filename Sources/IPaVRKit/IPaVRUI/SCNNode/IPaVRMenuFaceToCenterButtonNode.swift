//
//  IPaVRMenuFaceToCenterButtonNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/18.
//

import UIKit

public class IPaVRMenuFaceToCenterButtonNode: IPaVRMenuSimpleButtonNode {
    
    
    override var defaultImage:UIImage? {
        get {
            return self.createIconImage("location.fill")!
        }
    }
    @objc override public func buttonAction(_ sender:Any) {
        guard let scene = self.vrScene, let vrView = scene.view else {
            return
        }
        vrView.faceToCenter()
        scene.isShowVRMenu = true
    }
}

extension IPaVRMenuFaceToCenterButtonNode:IPaVRMenuSceneControl {
    public func setVRScene(_ scene: IPaVRVideoScene?) {
        
    }
}
