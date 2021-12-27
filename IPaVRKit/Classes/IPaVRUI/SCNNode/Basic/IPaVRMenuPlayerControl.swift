//
//  IPaVRMenuPlayerControl.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/18.
//

import Combine
import IPaAVPlayer
private var sceneCancellable: UInt8 = 0
private var sceneHandle: UInt8 = 0
public protocol IPaVRMenuPlayerControl:IPaVRMenuSceneControl {

    func setAVPlayer(_ player:IPaAVPlayer?)
}
extension IPaVRMenuPlayerControl {
    public var avPlayer:IPaAVPlayer? {
        get {
            return self.vrScene?.avPlayer
        }
    }
    public func setVRScene(_ scene: IPaVRVideoScene?) {
        self.setAVPlayer(scene?.avPlayer)
    }

}
