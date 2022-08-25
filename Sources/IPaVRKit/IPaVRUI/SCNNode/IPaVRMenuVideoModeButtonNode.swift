//
//  IPaVRMenuVideoModeButtonNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/18.
//

import SceneKit
import Combine
import SpriteKit
import IPaImageTool
public class IPaVRMenuVideoModeButtonNode: IPaVRMenuSimpleButtonNode {
    var videoModeAnyCancellable:AnyCancellable?
    lazy var originImage:UIImage = self.createTextIconImage("Origin",font:UIFont.systemFont(ofSize: 8))!
    lazy var houImage:UIImage = self.createTextIconImage("HOU",font:UIFont.systemFont(ofSize: 8))!
    lazy var sbsImage:UIImage = self.createTextIconImage("SBS",font:UIFont.systemFont(ofSize: 8))!
    override var defaultImage:UIImage? {
        return self.originImage
    }
 
    func reloadMode(_ mode:IPaVRVideoScene.VideoMode) {
        switch mode {
        case .origin:
            self.image = originImage
        case .hou:
            self.image = houImage
        case .sbs:
            self.image = sbsImage
        }
    }
    @objc override public func buttonAction(_ sender:Any) {
        guard let scene = self.vrScene else {
            return
        }
        if let newMode = IPaVRVideoScene.VideoMode(rawValue: scene.videoMode.rawValue+1) {
            scene.videoMode = newMode
        }
        else {
            scene.videoMode = .origin
        }
    }
}
extension IPaVRMenuVideoModeButtonNode:IPaVRMenuSceneControl {
    public func setVRScene(_ scene: IPaVRVideoScene?) {
        if let scene = scene {
            self.videoModeAnyCancellable = scene.publisher(for: \.videoMode).sink(receiveValue: { mode in
                self.reloadMode(mode)
            })
        }
        else {
            self.videoModeAnyCancellable = nil
        }
    }
}
