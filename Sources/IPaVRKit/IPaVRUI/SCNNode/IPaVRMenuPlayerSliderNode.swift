//
//  IPaVRMenuPlayerSliderNode.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/9.
//

import SceneKit
import SpriteKit
import Combine
import IPaAVPlayer
public class IPaVRMenuPlayerSliderNode: IPaVrMenuSliderNode {
    var playerAnyCancellable:AnyCancellable?
    override public  func setValue(_ newValue: CGFloat, animated: Bool) {
        super.setValue(newValue, animated: animated)
        guard let duration = self.avPlayer?.duration else {
            return
        }
        self.avPlayer?.seek(to: duration * Double(newValue)) { _ in }
        
    }
}
extension IPaVRMenuPlayerSliderNode:IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
        guard let player = player else {
            self.playerAnyCancellable = nil
            return
        }
        self._value = Float(player.currentTime / player.duration)
        self.progressSpriteNode.xScale = CGFloat(self._value)
        let currentTimePubliher = player.publisher(for:\.currentTime)
        let durationPublisher = player.publisher(for: \.duration)
        self.playerAnyCancellable = currentTimePubliher.merge(with: durationPublisher).sink(receiveValue: { [weak self, weak player] _ in
            guard let self, let player else { return }
            self._value = Float(player.currentTime / player.duration)
            self.progressSpriteNode.xScale = CGFloat(self._value)
        })
    }
}
