//
//  IPaVRMenuPlayLastButtonNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/17.
//

import IPaAVPlayer
import SceneKit
class IPaVRMenuPlayB10ButtonNode: IPaVRMenuSimpleButtonNode {
    override var defaultImage:UIImage? {
        return self.createIconImage("gobackward.10")
    }
    @objc override public func buttonAction(_ sender:Any) {
        guard let avPlayer = self.avPlayer else {
            return
        }
        let time = max(0,avPlayer.currentTime - 10)
        avPlayer.seekToTime(time, complete: nil)
    }
}
extension IPaVRMenuPlayB10ButtonNode:IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
    }
}
