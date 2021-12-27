//
//  IPaVRMenuPlayerFileNameNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/19.
//

import SceneKit
import Combine
import IPaAVPlayer
import AVFoundation
class IPaVRMenuPlayerFileNameNode: IPaVRMenuTextNode {
    var playerAnyCancellable:AnyCancellable?
}

extension IPaVRMenuPlayerFileNameNode :IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
        guard let player = player else {
            self.playerAnyCancellable = nil
            return
        }
        playerAnyCancellable = player.publisher(for: \.avPlayer.currentItem).sink(receiveValue: { item in
            guard let item = item else {
                self.playerAnyCancellable = nil
                return
            }
            for metaData in item.asset.commonMetadata {
                if metaData.commonKey == .commonKeyTitle,let title = metaData.value as? String {
                    self.text = title
                    return
                }
            }
            if let urlAsset = item.asset as? AVURLAsset {
                self.text = urlAsset.url.lastPathComponent
            }
            else {
                self.text = "Unknown"
            }
        })
        
        
//        self.playerAnyCancellable = player.publisher(for: \.duration)
    }
}
