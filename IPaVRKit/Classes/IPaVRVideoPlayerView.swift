//
//  IPaVRVideoPlayerView.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/11/23.
//

import UIKit
import SceneKit
import SpriteKit
import CoreMotion
import AVFoundation
import IPaAVPlayer
public class IPaVRVideoPlayerView: UIView,IPaVRPlayerSceneControllerDelegate {
    @objc public enum VideoMode:Int {
        case origin = 0
        case hou
        case sbs
    }
    @objc public enum VideoProjection:Int {
        case a360 = 0
        case a180
        case cinema
        case fullscreen
    }
    @objc dynamic public var avPlayer:IPaAVPlayer? {
        didSet {
             self.leftViewController.setAVPlayer(avPlayer?.avPlayer)
            self.rightViewController.setAVPlayer(avPlayer?.avPlayer)
         }
    }
        
    public var currentEularAngle = SCNVector3(x: 0, y: 0, z: 0) {
        didSet {
            self.leftViewController.cameraEularAngle = currentEularAngle
            self.rightViewController.cameraEularAngle = currentEularAngle
        }
    }
    lazy var _centerHeadAttiture:CMAttitude? = {
          return self.motionManager.deviceMotion?.attitude
    }()
    var centerHeadAttiture:CMAttitude? {
        get {
            if let _centerHeadAttiture = _centerHeadAttiture {
                return _centerHeadAttiture
            }
            self._centerHeadAttiture = self.motionManager.deviceMotion?.attitude
            return self._centerHeadAttiture
        }
        set {
            self._centerHeadAttiture = newValue
        }
    }
    lazy var motionManager:CMMotionManager = {
        let manager = CMMotionManager()
        manager.deviceMotionUpdateInterval = 1/60.0
        
        return manager
    }()
    var motionAttitude:CMAttitude? {
        return self.motionManager.deviceMotion?.attitude
    }
    var panGestureRecognizer:UIPanGestureRecognizer?
    var pinchGestureRecognizer:UIPinchGestureRecognizer?
    lazy var tapGestureRecognizer:UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTap(_:)))
        self.addGestureRecognizer(recognizer)
        return recognizer
    }()
    public var eyesInterval:Float = 10
    @objc dynamic public lazy var vrMenu:IPaVRMenu = {
        let menu = IPaVRMenu()
        menu.vrPlayerView = self
        let playButton = IPaVRMenuPlayButton("play")
        let y = menu.size.height * 0.5 - 40
        playButton.position = CGPoint(x: menu.size.width * 0.5, y: y)
        menu.addUIItem(playButton)
        
        return menu
    }() {
        didSet {
            guard oldValue != vrMenu else {
                return
            }
            vrMenu.vrPlayerView = self
            self.leftViewController.vrMenuNode = vrMenu.generateSCNNode()
            self.rightViewController.vrMenuNode = vrMenu.generateSCNNode()
        }
    }
    @objc dynamic public var isCardboardMode:Bool {
        get {
            return !self.rightViewController.view.isHidden
        }
        set {
            self.rightViewController.view.isHidden = !newValue
            let interval = self.eyesInterval * 0.5
            self.leftViewController.cameraOffsetX = newValue ? -interval : 0
            self.rightViewController.cameraOffsetX = newValue ? interval : 0
            
        }
    }
    @objc dynamic public var isShowVRMenu:Bool = false {
        didSet {
           
            self.tapGestureRecognizer.isEnabled = self.isShowVRMenu
            self.leftViewController.showVRMenu(isShowVRMenu)
            self.rightViewController.showVRMenu(isShowVRMenu)
            
        }
    }
    public var isTrackingHead:Bool {
        get {
            return motionManager.isDeviceMotionActive
        }
        set {
            
            if newValue {
                guard !motionManager.isDeviceMotionActive else {
                    return
                }
                motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
                self.faceToCenter()
                self.isPanEnable = false
            }
            else {
                motionManager.stopDeviceMotionUpdates()
            }
        }
    }
    
    public var isPanEnable:Bool {
        get {
            return self.panGestureRecognizer?.isEnabled ?? false
        }
        set {
            if !newValue {
                self.panGestureRecognizer?.isEnabled = false
            }
            else if self.panGestureRecognizer == nil {
                let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.onPan(_:)))
                self.addGestureRecognizer(gestureRecognizer)
                self.panGestureRecognizer = gestureRecognizer
            }
            else {
                self.panGestureRecognizer?.isEnabled = true
            }
            
        }
    }
    public var isPinchEnable:Bool {
        get {
            return self.pinchGestureRecognizer?.isEnabled ?? false
        }
        set {
            if !newValue {
                self.pinchGestureRecognizer?.isEnabled = false
            }
            else if self.pinchGestureRecognizer == nil {
                let gestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.onPinch(_:)))
                self.addGestureRecognizer(gestureRecognizer)
                self.pinchGestureRecognizer = gestureRecognizer
            }
            else {
                self.pinchGestureRecognizer?.isEnabled = true
            }
            
        }
    }
    var _videoZoom:CGFloat = 1 {
        didSet {
            self.currentProjection.videoZoom = _videoZoom
            self.reattachProjection()
        }
    }
    //videoZoom is between 1 ~ 2
    @objc dynamic public var videoZoom:CGFloat {
        get {
            return self._videoZoom
        }
        set {
            let newZoom = max(1,min(2,newValue))
            self._videoZoom = newZoom
            
        }
    }
  
    var currentProjection:IPaVRVideoProjection {
        get {
            return self.leftViewController.projection
        }
    }
    lazy var sphereProjection = IPaVRVideoSphereProjection()
    lazy var planeProjection = IPaVRVideoPlaneProjection()
    lazy var fullscreenProjection = IPaVRVideoFullScreenProjection()
    lazy var leftViewController = IPaVRPlayerSceneController(self,projection:self.sphereProjection)
    lazy var rightViewController = IPaVRPlayerSceneController(self,projection:self.sphereProjection)
    lazy var stackView:UIStackView = {
        let view = UIStackView()
        view.distribution = .fillEqually
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        return view
    }()
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    init(_ frame:CGRect) {
        super.init(frame: frame)
        self.initialSetting()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        self.initialSetting()
    }
    func initialSetting() {
        self.stackView.addArrangedSubview(self.leftViewController.view)
        self.stackView.addArrangedSubview(self.rightViewController.view)
        self.rightViewController.view.isHidden = true
        self.currentEularAngle = self.leftViewController.cameraEularAngle
    }
    func reattachProjection() {
        self.leftViewController.projection = self.currentProjection
        self.rightViewController.projection = self.currentProjection
    }
    public func faceToCenter() {
        self.leftViewController.faceToCenter()
        self.rightViewController.faceToCenter()
        
        self.currentEularAngle = self.leftViewController.cameraEularAngle
        
        self.centerHeadAttiture = self.motionAttitude
    }
    @objc func onTap(_ sender:UITapGestureRecognizer) {
        if let hitTestResult = self.vrMenu.currentHitTestResult {
            guard let node = hitTestResult.node as? IPaVRUIItemResponsableNode else {
                return
            }
            node.uiItem.onTap(hitTestResult)
        }
        else {
            self.isShowVRMenu = false
        }
    }
    @objc func onPinch(_ sender:UIPinchGestureRecognizer) {
        self.currentProjection.onPinch(sender, originZoom: self.videoZoom)
        if sender.state == .ended {
            self.videoZoom = self.currentProjection.videoZoom
        }
        else {
            self.reattachProjection()
        }
    }
    @objc func onPan(_ sender:UIPanGestureRecognizer) {
        var newEular = self.currentEularAngle
        let translation = sender.translation(in: self)
        newEular.y = self.currentEularAngle.y + Float(translation.x * 0.0025)
        newEular.x = self.currentEularAngle.x + Float(translation.y * 0.0025)
        if sender.state == .ended {
            self.currentEularAngle = newEular
        }
        else {
            self.leftViewController.cameraEularAngle = newEular
            self.rightViewController.cameraEularAngle = newEular
        }
    }

    func renderer(_ controller: IPaVRPlayerSceneController, updateAtTime time: TimeInterval)
    {
        if controller == self.leftViewController {
            controller.uiHitTest()
        }
    }
}


