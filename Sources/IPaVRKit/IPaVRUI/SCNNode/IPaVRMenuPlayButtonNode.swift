//
//  IPaVRMenuPlayButtonNode.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/10.
//

import SceneKit
import IPaImageTool
import Combine
import IPaAVPlayer
public class IPaVRMenuPlayButtonNode: IPaVRMenuSimpleButtonNode {
    var isPlayAnyCancellable:AnyCancellable?
    public lazy var pauseImage:UIImage = self.createIconImage("play.fill")!
    public lazy var playImage:UIImage = self.createIconImage("pause.fill")!
    @objc override public func buttonAction(_ sender:Any) {
        guard let avPlayer = self.avPlayer else {
            return
        }
        if avPlayer.isPlay {
            avPlayer.pause()
        }
        else {
            avPlayer.play()
        }
    }
    override var defaultImage:UIImage? {
     
        return self.pauseImage
    }
}
extension IPaVRMenuPlayButtonNode:IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
        guard let player = player else {
            self.isPlayAnyCancellable = nil
            self.image = self.pauseImage
            return
        }
        self.isPlayAnyCancellable = player.publisher(for:\.isPlay).sink(receiveValue: { isPlay in
            self.image = isPlay ? self.playImage : self.pauseImage
        })
    }
}
