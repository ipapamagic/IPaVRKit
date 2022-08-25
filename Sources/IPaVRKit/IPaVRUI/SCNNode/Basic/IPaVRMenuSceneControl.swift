//
//  IPaVRMenuSceneControl.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/18.
//

import SceneKit
import Combine
private var sceneCancellable: UInt8 = 0
private var sceneHandle: UInt8 = 0
public protocol IPaVRMenuSceneControl {
    func setVRScene(_ scene:IPaVRVideoScene?)
}

extension IPaVRMenuSceneControl {
    var vrSceneAnyCancellable:AnyCancellable? {
        get {
            return objc_getAssociatedObject(self, &sceneCancellable) as? AnyCancellable
        }
        set {
            objc_setAssociatedObject(self, &sceneCancellable, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    public var vrScene:IPaVRVideoScene? {
        get {
            return objc_getAssociatedObject(self, &sceneHandle) as? IPaVRVideoScene
        }
        set {
            objc_setAssociatedObject(self, &sceneHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            self.setVRScene(newValue)
        }

    }
}
