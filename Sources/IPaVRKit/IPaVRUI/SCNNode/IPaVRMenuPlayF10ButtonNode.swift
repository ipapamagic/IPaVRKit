//
//  IPaVRMenuPlayNextButtonNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/17.
//

import SceneKit
import IPaAVPlayer
class IPaVRMenuPlayF10ButtonNode: IPaVRMenuSimpleButtonNode {
    override var defaultImage:UIImage? {
        return self.createIconImage("goforward.10")
    }
    @objc override public func buttonAction(_ sender:Any) {
        guard let avPlayer = self.avPlayer else {
            return
        }
        let time = min(avPlayer.duration,avPlayer.currentTime + 10)
        avPlayer.seekToTime(time, complete: nil)
    }
}
extension IPaVRMenuPlayF10ButtonNode:IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
    }
}
