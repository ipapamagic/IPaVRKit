//
//  IPaVRMenuVideoProjButtonNode.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/18.
//

import SceneKit
import Combine

class IPaVRMenuVideoProjButtonNode: IPaVRMenuSimpleButtonNode {
    var videoProjAnyCancellable:AnyCancellable?
    lazy var a360Image:UIImage = self.createTextIconImage("360",font:UIFont.systemFont(ofSize: 8))!
    lazy var a180Image:UIImage = self.createTextIconImage("180",font:UIFont.systemFont(ofSize: 8))!
    lazy var cinemaImage:UIImage = self.createIconImage("tv")!
    lazy var cubeImage:UIImage = self.createIconImage("cube.fill")!
    override var defaultImage:UIImage? {
        return self.a360Image
    }
    
    func reloadProjection(_ projection:IPaVRVideoScene.VideoProjection) {
        switch projection {
        case .a180,.fullscreen:
            self.image = a180Image
        case .a360:
            self.image = a360Image
        case .cinema:
            self.image = cinemaImage
        case .cube:
            self.image = cubeImage
        }
    }
    @objc override public func buttonAction(_ sender:Any) {
        guard let scene = self.vrScene else {
            return
        }
        if let newProjection = IPaVRVideoScene.VideoProjection(rawValue: scene.videoProjection.rawValue+1),newProjection != .fullscreen {
            scene.videoProjection = newProjection
        }
        else {
            scene.videoProjection = .a360
        }
    }
}
extension IPaVRMenuVideoProjButtonNode:IPaVRMenuSceneControl {
    public func setVRScene(_ scene: IPaVRVideoScene?) {
        if let scene = scene {
            self.videoProjAnyCancellable = scene.publisher(for: \.videoProjection).sink(receiveValue: { projection in
                self.reloadProjection(projection)
            })
        }
        else {
            self.videoProjAnyCancellable = nil
        }
    }
}
