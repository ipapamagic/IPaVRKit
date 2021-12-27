//
//  IPaVRMenuItem.swift
//  IPaAVPlayer
//
//  Created by IPa Chen on 2021/12/9.
//

import SceneKit
import IPaAVPlayer
import Combine
private var sceneCancellable: UInt8 = 0
private var sceneHandle: UInt8 = 0
public protocol IPaVRMenuItem: SCNNode {
    
    var isHighlighted:Bool {get set}
    func onTap(_ result:SCNHitTestResult)
}
extension SCNNode {
    public func createIconImage(_ systemName:String?,size:CGSize = CGSize(width: 30, height: 30),iconColor:UIColor = .white,bgColor:UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)) -> UIImage? {
        let iconSize = CGSize(width:size.width * 0.4,height:size.height * 0.4)
        return UIImage.createImage(size) { context in
            
            
            context.setFillColor(bgColor.cgColor)
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            context.addPath(path.cgPath)
            context.fillPath()
            
            if let systemName = systemName, let icon = (UIImage(systemName: systemName)?.withTintColor(iconColor)) {
                icon.draw(in: CGRect(origin: CGPoint(x: (size.width - iconSize.width) * 0.5, y: (size.height - iconSize.height) * 0.5), size: iconSize))
            }
        }
    }
    public func createTextIconImage(_ text:String,font:UIFont,size:CGSize = CGSize(width: 30, height: 30),textColor:UIColor = .white,bgColor:UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)) -> UIImage? {
        return UIImage.createImage(size) { context in
            context.setFillColor(bgColor.cgColor)
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            context.addPath(path.cgPath)
            context.fillPath()
        
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (text as NSString).draw(in: CGRect(x: 0, y: size.height * 0.5 - font.lineHeight * 0.5, width: size.width, height: font.lineHeight), withAttributes: [.foregroundColor : textColor,.font:font,.paragraphStyle:paragraph])
        }
    }
}

