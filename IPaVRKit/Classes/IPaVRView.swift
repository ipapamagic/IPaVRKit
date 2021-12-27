//
//  IPaVRView.swift
//  IPaVRKit
//
//  Created by IPa Chen on 2021/12/11.
//

import UIKit
import CoreMotion
import SceneKit
public protocol IPaVRViewDelegate
{
    func onTap(_ view:IPaVRView, sender:UITapGestureRecognizer)
}
open class IPaVRView: UIView {
    public var delegate:IPaVRViewDelegate?
    public var vrScene:IPaVRScene? {
        didSet {
            oldValue?._view = nil
            self.leftView.scene = vrScene?.scene
            self.rightView.scene = vrScene?.scene
            self.leftView.pointOfView = vrScene?.leftCameraNode
            self.rightView.pointOfView = vrScene?.rightCameraNode
            vrScene?.onSetup(leftView, rightView: rightView)
            self.isCardboardMode = false
            vrScene?._view = self
        }
    }
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
    lazy var leftView:SCNView = {
        let view = SCNView()
        view.backgroundColor = .black
        view.delegate = self
        view.isPlaying = true
        return view
    }()
    lazy var rightView:SCNView = {
        let view = SCNView()
        view.backgroundColor = .black
        return view
    }()
    @objc dynamic public var eyesInterval:Float = 30 {
        didSet {
            self.vrScene?.eyesInterval = self.isCardboardMode ? self.eyesInterval : 0
        }
    }
    public let eyesIntervalRange = 0.0 ... 300.0
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
    
    
    var panGestureRecognizer:UIPanGestureRecognizer?
    var pinchGestureRecognizer:UIPinchGestureRecognizer?
    lazy var tapGestureRecognizer:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTap(_:)))
    
    var centerHeadAttiture = SCNVector3(0, 0, 0)
    var startPanCameraAngle = SCNVector3(x: 0, y: 0, z: 0)
    lazy var motionManager:CMMotionManager = {
        let manager = CMMotionManager()
        manager.deviceMotionUpdateInterval = 1/60.0
        
        return manager
    }()
    var motionAttitude:CMAttitude? {
        return self.motionManager.deviceMotion?.attitude
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
                
                motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, error in
                    if let currentAttitude = self.motionAttitude, self.isTrackingHead  {
   
                        self.vrScene?.currentEularAngle = SCNVector3( self.centerHeadAttiture.x - Float(currentAttitude.roll), Float(currentAttitude.yaw) - self.centerHeadAttiture.y, self.centerHeadAttiture.z - Float(currentAttitude.pitch))
                    }
                }
                self.centerHeadAttiture = SCNVector3(x: Float(self.motionAttitude?.roll ?? 0), y: Float(self.motionAttitude?.yaw ?? 0), z: Float(self.motionAttitude?.pitch ?? 0))
            }
            else {
                motionManager.stopDeviceMotionUpdates()
            }
        }
    }
    @objc dynamic public var isCardboardMode:Bool {
        get {
            return !self.rightView.isHidden
        }
        set {
            self.rightView.isHidden = !newValue
            self.rightView.isPlaying = newValue
            self.vrScene?.eyesInterval = newValue ? self.eyesInterval : 0
        }
    }
    init(_ frame:CGRect) {
        super.init(frame: frame)
        self.initialSetting()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        self.initialSetting()
    }
    func initialSetting() {
        self.stackView.addArrangedSubview(self.leftView)
        
        
        self.stackView.addArrangedSubview(self.rightView)
        
        self.isCardboardMode = true
        self.addGestureRecognizer(self.tapGestureRecognizer)
    }
    
    @objc func onTap(_ sender:UITapGestureRecognizer) {
        if !(self.vrScene?.onTap() ?? false) {
            self.delegate?.onTap(self, sender: sender)
            
        }

    }
    @objc func onPinch(_ sender:UIPinchGestureRecognizer) {
//        self.currentProjection.onPinch(sender, originZoom: self.videoZoom)
//        if sender.state == .ended {
//            self.videoZoom = self.currentProjection.videoZoom
//        }
//        else {
//            self.reattachProjection()
//        }
    }
    @objc func onPan(_ sender:UIPanGestureRecognizer) {
        
        if sender.state == .began {
            self.startPanCameraAngle = self.vrScene?.currentEularAngle ?? SCNVector3(x: 0, y: 0, z: 0)
        }
        else {
            let translation = sender.translation(in: self)
            var newEular = self.startPanCameraAngle
            newEular.y = newEular.y + Float(translation.x * 0.0025)
            newEular.x = newEular.x + Float(translation.y * 0.0025)
            self.vrScene?.currentEularAngle = newEular
            
            //update center for enable track
            self.centerHeadAttiture.x = newEular.x + Float(self.motionAttitude?.roll ?? 0)
            self.centerHeadAttiture.y =  Float(self.motionAttitude?.yaw ?? 0) - newEular.y
            self.centerHeadAttiture.z =  Float(self.motionAttitude?.pitch ?? 0) + newEular.z
            
        }
    }
    public func faceToCenter() {
        self.centerHeadAttiture = SCNVector3(x: Float(self.motionAttitude?.roll ?? 0), y: Float(self.motionAttitude?.yaw ?? 0), z: Float(self.motionAttitude?.pitch ?? 0))
        self.vrScene?.faceToCenter()
    }
    open func hitTest(_ point: CGPoint, options: [SCNHitTestOption : Any]? = nil) -> [SCNHitTestResult]
    {
        let transform = CGAffineTransform(scaleX: self.leftView.bounds.width, y: self.leftView.bounds.height)
        let newPoint = point.applying(transform)
        return self.leftView.hitTest(newPoint, options: options)
    }

}
extension IPaVRView :SCNSceneRendererDelegate
{
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.vrScene?.renderer(self, updateAtTime: time)
        
    }
}
