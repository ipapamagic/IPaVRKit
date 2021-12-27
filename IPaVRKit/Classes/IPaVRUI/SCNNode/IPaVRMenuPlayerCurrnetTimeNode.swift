//
//  IPaVRMenuPlayerCurrnetTimeNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/19.
//

import IPaAVPlayer
import Combine
public class IPaVRMenuPlayerCurrnetTimeNode: IPaVRMenuTextNode {
    var playerAnyCancellable:AnyCancellable?
}



extension IPaVRMenuPlayerCurrnetTimeNode :IPaVRMenuPlayerControl {
    public func setAVPlayer(_ player: IPaAVPlayer?) {
        guard let player = player else {
            self.playerAnyCancellable = nil
            return
        }
        self.playerAnyCancellable = player.publisher(for: \.currentTime).map({
            currentTime in
            let second = Int(currentTime) % 60
            var minute = Int(currentTime)
            / 60
            let hour = minute / 60
            minute = minute % 60
            if hour == 0 {
                return String(format: "%.2d:%.2d", minute,second)
            }
            else {
                return String(format: "%d%.2d:%.2d",hour, minute,second)
            }
        }).assign(to: \.text, on: self)
    }
}
