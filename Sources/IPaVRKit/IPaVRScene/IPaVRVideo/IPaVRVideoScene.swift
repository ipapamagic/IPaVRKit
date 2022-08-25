//
//  IPaVRVideoScene.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/11.
//

import SceneKit
import SpriteKit
import IPaAVPlayer
import Combine
public class IPaVRVideoScene: IPaVRScene {
    let vrMenuZValue:Float = -300
    let vrAimZValue:Float = -280
    let hitTestZValue:Float = -1000
    @objc public enum VideoMode:Int {
        case origin = 0
        case hou
        case sbs
    }
    @objc public enum VideoProjection:Int {
        case a360 = 0
        case a180
        case cinema
        case cube
        case fullscreen
    }
    public override var leftCameraNode: SCNNode {
        get {
            return vrLCamera.camera
        }
    }
    
    public override var rightCameraNode: SCNNode {
        get {
            return vrRCamera.camera
        }
    }
    
    
    lazy var vrLCamera:IPaVRVideoCamera = {
        let camera = IPaVRVideoCamera()
        camera.camera.camera?.categoryBitMask = ~0 ^ 2
        camera.scene = self
        return camera
    }()
    @objc dynamic lazy var vrRCamera:IPaVRVideoCamera = {
        let camera = IPaVRVideoCamera()
        camera.camera.camera?.categoryBitMask = ~0 ^ 4
        camera.scene = self
        return camera
    }()
    
    var videoZoom:CGFloat = 1
    var videoSizeAnyCancellable:AnyCancellable?
    var playerAnyCancellable:AnyCancellable?
    
    @objc dynamic public var avPlayer:IPaAVPlayer {
        didSet {
            self.setupPlayer()
        }
    }
    @objc dynamic public var videoMode:VideoMode = .origin {
        didSet {
            switch videoMode {
            case .origin:
                self.vrLCamera.videoRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                self.vrRCamera.videoRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            case .hou:
                self.vrLCamera.videoRect = CGRect(x: 0, y: -1, width: 1, height: 2)
                self.vrRCamera.videoRect = CGRect(x: 0, y: 0, width: 1, height: 2)
            case .sbs:
                self.vrLCamera.videoRect = CGRect(x: 0, y: 0, width: 2, height: 1)
                self.vrRCamera.videoRect = CGRect(x: -1, y: 0, width: 2, height: 1)
            }
            self.reattachProjection()
        }
    }
    @objc dynamic public var videoProjection:VideoProjection = .fullscreen {
        didSet {
            switch videoProjection {
            case .fullscreen:
                self.currentProjection = self.fullScreenProjection
            case .a180:
                self.sphereProjection.is360 = false
                self.currentProjection = self.sphereProjection
            case .a360:
                self.sphereProjection.is360 = true
                self.currentProjection = self.sphereProjection
            case .cube:
                self.currentProjection = self.cubeProjection
            case .cinema:
                self.currentProjection = self.planeProjection
            }
        }
    }
    @objc dynamic public var isShowVRMenu:Bool {
        get {
            return !self.vrMenu.isHidden
        }
        set {
            self.vrMenu.isHidden = !newValue
            self.aimNode.isHidden = self.vrMenu.isHidden
            if newValue {
                var position = self.cameraRootNode.position
                position.z = self.vrMenuZValue
                self.vrMenu.eulerAngles = self.cameraRootNode.eulerAngles
                self.vrMenu.position = self.cameraRootNode.convertPosition(position, to: nil)
            }
           
        }
    }
    lazy var aimNode:IPaVRAimNode = {
        let node = IPaVRAimNode()
        self.cameraRootNode.addChildNode(node)
        node.position = SCNVector3(0, 0, self.vrAimZValue)
        node.isHidden = true
        return node
    }()
    public lazy var vrMenu:IPaVRMenuNode = {
        let menu = IPaVRMenuNode()
        menu.isHidden = true
        self.scene.rootNode.addChildNode(menu)
        //play button
        var playButton = IPaVRMenuPlayButtonNode()
        playButton.position = SCNVector3(0, 10, 10)
        playButton.vrScene = self
        menu.addChildNode(playButton)
        //fast forward 10 sec
        var forwardButton = IPaVRMenuPlayF10ButtonNode()
        forwardButton.position = SCNVector3(65, 10, 10)
        forwardButton.vrScene = self
        menu.addChildNode(forwardButton)
        //fast backward 10 sec
        var backwardButton = IPaVRMenuPlayB10ButtonNode()
        backwardButton.position = SCNVector3(-65, 10, 10)
        backwardButton.vrScene = self
        menu.addChildNode(backwardButton)
        
        //slider
        var progressSlider = IPaVRMenuPlayerSliderNode()
        progressSlider.position = SCNVector3(0,-65,10)
        progressSlider.vrScene = self
        menu.addChildNode(progressSlider)
        
        var videoModeButton = IPaVRMenuVideoModeButtonNode()
        videoModeButton.position = SCNVector3(-65,-30,10)
        videoModeButton.vrScene = self
        menu.addChildNode(videoModeButton)
        
        var videoProjButton = IPaVRMenuVideoProjButtonNode()
        videoProjButton.position = SCNVector3(65,-30,10)
        videoProjButton.vrScene = self
        menu.addChildNode(videoProjButton)
        
        var faceToCenterButton = IPaVRMenuFaceToCenterButtonNode()
        faceToCenterButton.position = SCNVector3(x: 0, y: -30, z: 10)
        faceToCenterButton.vrScene = self
        menu.addChildNode(faceToCenterButton)
        
        var startTimeLabel = IPaVRMenuPlayerCurrnetTimeNode()
        startTimeLabel.vrScene = self
        startTimeLabel.position = SCNVector3(x: progressSlider.position.x - Float(progressSlider.size.width) * 0.5 - 20, y: progressSlider.position.y, z: 10)
        menu.addChildNode(startTimeLabel)
        
        var durationLabel = IPaVRMenuPlayerDurationNode()
        durationLabel.vrScene = self
        durationLabel.position = SCNVector3(x: progressSlider.position.x + Float(progressSlider.size.width) * 0.5 + 20, y: progressSlider.position.y, z: 10)
        menu.addChildNode(durationLabel)
        
        var fileNameLabel = IPaVRMenuPlayerFileNameNode()
        fileNameLabel.vrScene = self
        fileNameLabel.position = SCNVector3(x: 0, y: -75, z: 10)
        menu.addChildNode(fileNameLabel)
        
        return menu
    }()
    lazy var fullScreenProjection = IPaVRVideoFullScreenProjection()
    lazy var sphereProjection = IPaVRVideoSphereProjection()
    lazy var planeProjection = IPaVRVideoPlaneProjection()
    lazy var cubeProjection = IPaVRVideoCubeProjection()
    lazy var currentProjection:IPaVRVideoProjection = self.fullScreenProjection {
        didSet {
            oldValue.detach(from: self, camera: self.vrLCamera)
            oldValue.detach(from: self, camera: self.vrRCamera)
            
            self.reattachProjection()
        }
    }
    
    var videoSize = CGSize(width: 1, height: 1) {
        didSet {
            guard !videoSize.equalTo(oldValue) else {
                return
            }
            self.reattachProjection()
        }
    }
    
    public init(_ avPlayer:IPaAVPlayer) {
        self.avPlayer = avPlayer
        super.init()
        self.setupPlayer()
        
    }
    public override func onSetup(_ leftView:SCNView,rightView:SCNView) {
        self.vrLCamera.view = leftView
        self.vrRCamera.view = rightView
        self.reattachProjection()
    }
    public override func onTap() -> Bool {
        if let hitTestResult = self.vrMenu.currentHitTestResult {
            guard let node = hitTestResult.node as? IPaVRMenuItem else {
                return false
            }
            node.onTap(hitTestResult)
            return true
        }
        return false
    }
    func reattachProjection() {
        currentProjection.attach(self, camera: vrLCamera)
        currentProjection.attach(self, camera: vrRCamera)
    }
    func setupPlayer() {
        self.videoSizeAnyCancellable = avPlayer.publisher(for: \.avPlayer.currentItem?.presentationSize,options: [.initial,.new]).sink(receiveValue: { size in
            var newSize = size ?? CGSize(width: 1, height: 1)
            if newSize.equalTo(.zero) {
                newSize = CGSize(width: 1, height: 1)
            }
            self.videoSize = newSize
        })
        self.playerAnyCancellable = avPlayer.publisher(for: \.avPlayer,options: [.initial,.new]).sink(receiveValue: { player in
            self.vrLCamera.spriteVideoNode = SKVideoNode(avPlayer: player)
            self.vrRCamera.spriteVideoNode = SKVideoNode(avPlayer: player)
            self.reattachProjection()
        })
    }
    
    public override func renderer(_ view: IPaVRView, updateAtTime time: TimeInterval) {
        let position = self.cameraRootNode.convertPosition(SCNVector3(0, 0, self.hitTestZValue), to: nil)
        self.vrMenu.currentHitTestResult = self.scene.rootNode.hitTestWithSegment(from: self.cameraRootNode.position, to: position, options: [SCNHitTestOption.categoryBitMask.rawValue:IPaVRMenuNode.vrMenuItemBitMask]).first
        self.aimNode.targetSelected = (self.vrMenu.currentHitTestResult != nil)
//        self.vrMenu.currentHitTestResult = view.hitTest(CGPoint(x: 0.5, y: 0.5), options: [.categoryBitMask:IPaVRMenuNode.vrMenuItemBitMask]).first
    }
}
