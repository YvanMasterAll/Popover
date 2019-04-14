//
//  Popover.swift
//  Popover
//
//  Created by corin8823 on 8/16/15.
//  Copyright (c) 2015 corin8823. All rights reserved.
//

import Foundation
import UIKit

public enum PopoverOption {
    case arrowSize(CGSize)
    case animationIn(TimeInterval)
    case animationOut(TimeInterval)
    case cornerRadius(CGFloat)
    case sideEdge(CGFloat)
    case blackOverlayColor(UIColor)
    case overlayBlur(UIBlurEffect.Style)
    case type(PopoverType)
    case color(UIColor)
    case dismissOnBlackOverlayTap(Bool)
    case showBlackOverlay(Bool)
    case highlightCornerRadius(CGFloat)
    case springDamping(CGFloat)
    case initialSpringVelocity(CGFloat)
}

@objc public enum PopoverType: Int {
    case up
    case down
    case left
    case right
    case auto
}

@objc public enum PopoverDialogType: Int {
    case dialog_arrow
    case dialog_default
}

@objcMembers
open class Popover: UIView {
    
    // custom property
    open var arrowSize                  : CGSize        = CGSize(width: 16.0, height: 10.0)
    open var animationIn                : TimeInterval  = 0.6
    open var animationOut               : TimeInterval  = 0.3
    open var cornerRadius               : CGFloat       = 6.0
    open var sideEdge                   : CGFloat       = 20.0
    open var popoverType                : PopoverType   = .auto
    open var blackOverlayColor          : UIColor       = UIColor(white: 0.0, alpha: 0.2)
    open var overlayBlur                : UIBlurEffect?
    open var popoverColor               : UIColor       = UIColor.white
    open var dismissOnBlackOverlayTap   : Bool          = true
    open var showBlackOverlay           : Bool          = true
    open var highlightFromView          : Bool          = false
    open var highlightCornerRadius      : CGFloat       = 0
    open var springDamping              : CGFloat       = 0.7
    open var initialSpringVelocity      : CGFloat       = 3
    
    // custom closure
    open var willShowHandler            : (() -> ())?
    open var willDismissHandler         : (() -> ())?
    open var didShowHandler             : (() -> ())?
    open var didDismissHandler          : (() -> ())?
    
    public fileprivate(set) var blackOverlay: UIControl = UIControl()

    open var contentView                : UIView!
    fileprivate var arrowShowPoint      : CGPoint!
    open var parent                     : UIViewController!
    open var child                      : UIViewController!
    fileprivate weak var sender         : UIView!
    fileprivate var dialogtype          : PopoverDialogType = .dialog_arrow
    
    open func show() {
        guard parent != nil else { return }
        //view layout
        parent.view.addSubview(self)
        self.backgroundColor = .clear
        //self.clipsToBounds = true
        if child != nil, let _sender = child.popover.sender {
            sender = _sender
            self.frame = .init(origin: .zero, size: child.popover.contentSize)
            parent.po_addchild(child, inview: self)
            child.view.frame = .init(origin: .zero, size: child.popover.contentSize)
            contentView = child.view
            if let _dialogtype = child.popover.dialogtype { dialogtype = _dialogtype }
            if let _options = child.popover.options { setOptions(_options) }
        } else if contentView != nil, let _sender = contentView.popover.sender {
            sender = _sender
            self.frame = .init(origin: .zero, size: contentView.popover.contentSize)
            if let _dialogtype = contentView.popover.dialogtype { dialogtype = _dialogtype }
            if let _options = contentView.popover.options { setOptions(_options) }
            contentView.frame = .init(origin: .zero, size: contentView.popover.contentSize)
            self.addSubview(contentView)
        } else { return }
        self.contentView.layer.cornerRadius = self.cornerRadius
        self.contentView.layer.masksToBounds = true
        //caculate arrow show point
        switch dialogtype {
        case .dialog_arrow:
            self.arrowShowPoint = getArrowShowPoint()
            highlightFromView = true
        case .dialog_default:
            self.arrowSize = .zero
            self.arrowShowPoint = CGPoint(x: parent.view.center.x,
                                          y: parent.view.center.y - contentView.frame.height/2)
        }
        //hightlight effect for sender
        if self.highlightFromView {
            self.createHighlightLayer(fromView: sender, inView: parent.view)
        }
        //overlay layer
        self.showOverlay()
        parent.view.setNeedsDisplay()
        //caculate location
        self.caculateLocation()
        //animation for wrapper
        self.applyAnimation()
        //draw wrapper layer with arrowpoint
        drawBackgroundLayerWithArrowPoint()
    }
    
    @objc open func _dismiss() {
        self.willDismissHandler?()
        UIView.animate(withDuration: self.animationOut, delay: 0,
                       options: UIView.AnimationOptions(),
                       animations: {
                        self.transform = CGAffineTransform(scaleX: 0.0001, y: 0.0001)
                        self.blackOverlay.alpha = 0
        }){ _ in
            self.contentView.removeFromSuperview()
            self.blackOverlay.removeFromSuperview()
            self.removeFromSuperview()
            self.transform = CGAffineTransform.identity
            self.didDismissHandler?()
        }
    }
}

//MARK: - Options Extends
private extension Popover {
    
    func setOptions(_ options: [PopoverOption]?){
        if let options = options {
            for option in options {
                switch option {
                case let .arrowSize(value):
                    self.arrowSize = value
                case let .animationIn(value):
                    self.animationIn = value
                case let .animationOut(value):
                    self.animationOut = value
                case let .cornerRadius(value):
                    self.cornerRadius = value
                case let .sideEdge(value):
                    self.sideEdge = value
                case let .blackOverlayColor(value):
                    self.blackOverlayColor = value
                case let .overlayBlur(style):
                    self.overlayBlur = UIBlurEffect(style: style)
                case let .type(value):
                    self.popoverType = value
                case let .color(value):
                    self.popoverColor = value
                case let .dismissOnBlackOverlayTap(value):
                    self.dismissOnBlackOverlayTap = value
                case let .showBlackOverlay(value):
                    self.showBlackOverlay = value
                case let .highlightCornerRadius(value):
                    self.highlightCornerRadius = value
                case let .springDamping(value):
                    self.springDamping = value
                case let .initialSpringVelocity(value):
                    self.initialSpringVelocity = value
                }
            }
        }
    }
}

//MARK: - Location Caculation
extension Popover {
    
    open func caculateLocation() {
        //caculate contentview location
        switch self.popoverType {
        case .up:
            self.contentView.frame.origin.y = -self.arrowSize.height
        case .down, .auto:
            self.contentView.frame.origin.y = self.arrowSize.height
        case .left:
            self.contentView.frame.origin.x = -self.arrowSize.height
        case .right:
            self.contentView.frame.origin.x = self.arrowSize.height
        }
        //caculate wrapper location
        switch popoverType {
        case .up, .down, .auto:
            self.frame.origin.x = self.arrowShowPoint.x - self.frame.size.width * 0.5
            
            var sideEdge: CGFloat = 0.0
            if self.frame.size.width < parent.view.frame.size.width {
                sideEdge = self.sideEdge
            }
            
            let outerSideEdge = self.frame.maxX - parent.view.bounds.size.width
            if outerSideEdge > 0 {
                self.frame.origin.x -= (outerSideEdge + sideEdge)
            } else {
                if self.frame.minX < 0 {
                    self.frame.origin.x += abs(self.frame.minX) + sideEdge
                }
            }
        case .left, .right:
            self.frame.origin.y = self.arrowShowPoint.y - self.frame.size.height * 0.5
            
            var sideEdge: CGFloat = 0.0
            if self.frame.size.height < parent.view.frame.size.height {
                sideEdge = self.sideEdge
            }
            
            let outerSideEdge = self.frame.maxY - parent.view.bounds.size.height
            if outerSideEdge > 0 {
                self.frame.origin.y -= (outerSideEdge + sideEdge)
            } else {
                if self.frame.minY < 0 {
                    self.frame.origin.y += abs(self.frame.minY) + sideEdge
                }
            }
        }
        
        let arrowPoint = parent.view.convert(self.arrowShowPoint, to: self)
        var anchorPoint: CGPoint
        switch self.popoverType {
        case .up:
            self.frame.origin.y = self.arrowShowPoint.y - self.frame.height - self.arrowSize.height
            anchorPoint = CGPoint(x: arrowPoint.x / self.frame.size.width, y: 1)
        case .down, .auto:
            self.frame.origin.y = self.arrowShowPoint.y
            anchorPoint = CGPoint(x: arrowPoint.x / self.frame.size.width, y: 0)
        case .left:
            self.frame.origin.x = self.arrowShowPoint.x - self.frame.width - self.arrowSize.height
            anchorPoint = CGPoint(x: 1, y: arrowPoint.y / self.frame.size.height)
        case .right:
            self.frame.origin.x = self.arrowShowPoint.x
            anchorPoint = CGPoint(x: 0, y: arrowPoint.y / self.frame.size.height)
        }
        
        if self.arrowSize == .zero {
            anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        
        let lastAnchor = self.layer.anchorPoint
        self.layer.anchorPoint = anchorPoint
        let x = self.layer.position.x + (anchorPoint.x - lastAnchor.x) * self.layer.bounds.size.width
        let y = self.layer.position.y + (anchorPoint.y - lastAnchor.y) * self.layer.bounds.size.height
        self.layer.position = CGPoint(x: x, y: y)
        //adjust location to show arrow point
        switch popoverType {
        case .up, .down, .auto:
            self.frame.size.height += self.arrowSize.height
            if self.frame.size.height != self.contentView.frame.size.height {
                self.contentView.frame.size.height += self.arrowSize.height
            }
        case .left, .right:
            self.frame.size.width += self.arrowSize.height
            if self.frame.size.width != self.contentView.frame.size.width {
                self.contentView.frame.size.width += self.arrowSize.height
            }
        }
        switch popoverType {
        case .up:
            self.contentView.frame.origin.y += arrowSize.height
        case .down, .auto:
            self.contentView.frame.origin.y -= arrowSize.height
        case .left:
            self.contentView.frame.origin.x += arrowSize.height
        case .right:
            self.contentView.frame.origin.x -= arrowSize.height
        }
    }
    
    open func getArrowShowPoint() -> CGPoint {
        let point: CGPoint
        
        if self.popoverType == .auto {
            if let point = sender.superview?.convert(sender.frame.origin, to: nil),
                point.y + sender.frame.height + self.arrowSize.height + self.frame.height > parent.view.frame.height {
                self.popoverType = .up
            } else {
                self.popoverType = .down
            }
        }
        
        switch self.popoverType {
        case .up:
            point = parent.view.convert(
                CGPoint(
                    x: sender.frame.origin.x + (sender.frame.size.width / 2),
                    y: sender.frame.origin.y
            ), from: sender.superview)
        case .down, .auto:
            point = parent.view.convert(
                CGPoint(
                    x: sender.frame.origin.x + (sender.frame.size.width / 2),
                    y: sender.frame.origin.y + sender.frame.size.height
            ), from: sender.superview)
        case .left:
            point = parent.view.convert(
                CGPoint(
                    x: sender.frame.origin.x,
                    y: sender.frame.origin.y + (sender.frame.size.height / 2)
            ), from: sender.superview)
        case .right:
            point = parent.view.convert(
                CGPoint(
                    x: sender.frame.origin.x + sender.frame.size.width,
                    y: sender.frame.origin.y + (sender.frame.size.height / 2)
            ), from: sender.superview)
        }
        
        return point
    }
}

//MARK: - Overlay + Highlight
extension Popover {
    
    open func showOverlay() {
        if self.dismissOnBlackOverlayTap || self.showBlackOverlay {
            self.blackOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.blackOverlay.frame = parent.view.bounds
            parent.view.insertSubview(self.blackOverlay, at: 0)
            
            if showBlackOverlay {
                if let overlayBlur = self.overlayBlur {
                    let effectView = UIVisualEffectView(effect: overlayBlur)
                    effectView.frame = self.blackOverlay.bounds
                    effectView.isUserInteractionEnabled = false
                    self.blackOverlay.addSubview(effectView)
                } else {
                    if !self.highlightFromView {
                        self.blackOverlay.backgroundColor = self.blackOverlayColor
                    }
                    self.blackOverlay.alpha = 0
                }
            }
            
            if self.dismissOnBlackOverlayTap {
                self.blackOverlay.addTarget(self, action: #selector(_dismiss), for: .touchUpInside)
            }
        }
    }
    
    func createHighlightLayer(fromView: UIView, inView: UIView) {
        let path = UIBezierPath(rect: inView.bounds)
        let highlightRect = inView.convert(fromView.frame, from: fromView.superview)
        let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: self.highlightCornerRadius)
        path.append(highlightPath)
        path.usesEvenOddFillRule = true

        let fillLayer = CAShapeLayer()
        fillLayer.path = path.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.fillColor = self.blackOverlayColor.cgColor
        self.blackOverlay.layer.addSublayer(fillLayer)
    }
}

//MARK: - Animations
extension Popover {
    
    open func applyAnimation() {
        self.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
        self.willShowHandler?()
        UIView.animate(
            withDuration: self.animationIn,
            delay: 0,
            usingSpringWithDamping: self.springDamping,
            initialSpringVelocity: self.initialSpringVelocity,
            options: UIView.AnimationOptions(),
            animations: {
                self.transform = CGAffineTransform.identity
        }){ _ in
            self.didShowHandler?()
        }
        UIView.animate(
            withDuration: self.animationIn / 3,
            delay: 0,
            options: .curveLinear,
            animations: {
                self.blackOverlay.alpha = 1
        }, completion: nil)
    }
}

//MARK: - Arrow Poing Darwing
extension Popover {
    
    fileprivate func drawBackgroundLayerWithArrowPoint() {
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.path = getArrowPointPath().cgPath
        backgroundLayer.fillColor = self.popoverColor.cgColor
        self.layer.insertSublayer(backgroundLayer, at: 0)
        self.layer.mask = backgroundLayer
    }
    
    func getArrowPointPath() -> UIBezierPath {
        let height = self.contentView.bounds.height
        let width = self.contentView.bounds.width
        let arrow = UIBezierPath()
        let color = self.popoverColor
        let arrowPoint = parent.view.convert(self.arrowShowPoint, to: self.contentView)
        switch self.popoverType {
        case .up:
            arrow.move(to: CGPoint(x: arrowPoint.x, y: height))
            arrow.addLine(
                to: CGPoint(
                    x: arrowPoint.x - self.arrowSize.width * 0.5,
                    y: self.isCornerLeftArrow ? self.arrowSize.height : height - self.arrowSize.height
                )
            )
            
            arrow.addLine(to: CGPoint(x: self.cornerRadius, y: height - self.arrowSize.height))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: height - self.arrowSize.height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(90),
                endAngle: self.radians(180),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: 0, y: self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(180),
                endAngle: self.radians(270),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width - self.cornerRadius, y: 0))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(270),
                endAngle: self.radians(0),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width, y: height - self.arrowSize.height - self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: height - self.arrowSize.height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(0),
                endAngle: self.radians(90),
                clockwise: true)
            
            arrow.addLine(
                to: CGPoint(
                    x: arrowPoint.x + self.arrowSize.width * 0.5,
                    y: self.isCornerRightArrow ? self.arrowSize.height : height - self.arrowSize.height
                )
            )
        case .down, .auto:
            arrow.move(to: CGPoint(x: arrowPoint.x, y: 0))
            arrow.addLine(
                to: CGPoint(
                    x: arrowPoint.x + self.arrowSize.width * 0.5,
                    y: self.isCornerRightArrow ? self.arrowSize.height + height : self.arrowSize.height
                )
            )
            
            arrow.addLine(to: CGPoint(x: width - self.cornerRadius, y: self.arrowSize.height))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: self.arrowSize.height + self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(270.0),
                endAngle: self.radians(0),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width, y: height - self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(0),
                endAngle: self.radians(90),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: 0, y: height))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(90),
                endAngle: self.radians(180),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: 0, y: self.arrowSize.height + self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: self.arrowSize.height + self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(180),
                endAngle: self.radians(270),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(
                x: arrowPoint.x - self.arrowSize.width * 0.5,
                y: self.isCornerLeftArrow ? self.arrowSize.height + height : self.arrowSize.height))
        case .left:
            arrow.move(to: CGPoint(x: width, y: arrowPoint.y))
            arrow.addLine(
                to: CGPoint(
                    x: self.isCornerDownArrow ? self.arrowSize.height : width - self.arrowSize.height,
                    y: arrowPoint.y + self.arrowSize.width * 0.5
                )
            )
            
            arrow.addLine(to: CGPoint(x: width - self.arrowSize.height, y: height - self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.arrowSize.height - self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(0),
                endAngle: self.radians(90),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: self.cornerRadius, y: height))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(90),
                endAngle: self.radians(180),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: 0, y: self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(180),
                endAngle: self.radians(270),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width - self.arrowSize.height - self.cornerRadius, y: 0))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.arrowSize.height - self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(270),
                endAngle: self.radians(0),
                clockwise: true)
            
            arrow.addLine(
                to: CGPoint(
                    x: self.isCornerUpArrow ? self.arrowSize.height : width - self.arrowSize.height,
                    y: arrowPoint.y - self.arrowSize.width * 0.5
                )
            )
        case .right:
            arrow.move(to: CGPoint(x: 0, y: arrowPoint.y))
            arrow.addLine(
                to: CGPoint(
                    x: self.isCornerUpArrow ? width - self.arrowSize.height : self.arrowSize.height,
                    y: arrowPoint.y - self.arrowSize.width * 0.5
                )
            )
            
            arrow.addLine(to: CGPoint(x: self.arrowSize.height, y: self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.arrowSize.height + self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(180),
                endAngle: self.radians(270),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width - self.cornerRadius, y: 0))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(270),
                endAngle: self.radians(0),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: width, y: height - self.cornerRadius))
            arrow.addArc(
                withCenter: CGPoint(
                    x: width - self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(0),
                endAngle: self.radians(90),
                clockwise: true)
            
            arrow.addLine(to: CGPoint(x: self.arrowSize.height + self.cornerRadius, y: height))
            arrow.addArc(
                withCenter: CGPoint(
                    x: self.arrowSize.height + self.cornerRadius,
                    y: height - self.cornerRadius
                ),
                radius: self.cornerRadius,
                startAngle: self.radians(90),
                endAngle: self.radians(180),
                clockwise: true)
            
            arrow.addLine(
                to: CGPoint(
                    x: self.isCornerDownArrow ? width - self.arrowSize.height : self.arrowSize.height,
                    y: arrowPoint.y + self.arrowSize.width * 0.5
                )
            )
        }
        
        color.setFill()
        arrow.fill()
        return arrow
    }
    
    func radians(_ degrees: CGFloat) -> CGFloat {
        return CGFloat.pi * degrees / 180
    }
    
    var isCornerLeftArrow: Bool {
        return self.arrowShowPoint.x == self.frame.origin.x
    }
    
    var isCornerRightArrow: Bool {
        return self.arrowShowPoint.x == self.frame.origin.x + self.bounds.width
    }
    
    var isCornerUpArrow: Bool {
        return self.arrowShowPoint.y == self.frame.origin.y
    }
    
    var isCornerDownArrow: Bool {
        return self.arrowShowPoint.y == self.frame.origin.y + self.bounds.height
    }
}

//MARK: - Protocol + Extension

public protocol Popoverable {
    
    associatedtype CompatibleType
    
    var popover: PopoverImpl<CompatibleType> { get set }
}

extension Popoverable {
    
    public var popover: PopoverImpl<Self> {
        get { return PopoverImpl(self) }
        set { }
    }
}

open class PopoverImpl<Base> {
    public let base: Base
    
    init(_ base: Base) {
        self.base = base
    }
}

extension PopoverImpl where Base: UIViewController {
    
    public var contentSize: CGSize {
        get { return (objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_ContentSize) as? CGSize) ?? CGSize(width: 100, height: 100) }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_ContentSize, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var child: UIViewController? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Child) as? UIViewController }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Child, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public weak var sender: UIView? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Sender) as? UIView }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Sender, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var dialogtype: PopoverDialogType? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Dialogtype) as? PopoverDialogType }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Dialogtype, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var options: [PopoverOption]? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Options) as? [PopoverOption] }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Options, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension PopoverImpl where Base: UIView {
    
    public var contentSize: CGSize {
        get { return (objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_ContentSize) as? CGSize) ?? CGSize(width: 100, height: 100) }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_ContentSize, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public weak var sender: UIView? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Sender) as? UIView }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Sender, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var dialogtype: PopoverDialogType? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Dialogtype) as? PopoverDialogType }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Dialogtype, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var options: [PopoverOption]? {
        get { return objc_getAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Options) as? [PopoverOption] }
        set { objc_setAssociatedObject(base, &type(of: base).po_AssociatedKeys.po_Options, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension UIViewController {
    
    fileprivate struct po_AssociatedKeys {
        static var po_ContentSize       = "po_ContentSize"
        static var po_Child             = "po_Child"
        static var po_Sender            = "po_Sender"
        static var po_Dialogtype        = "po_Dialogtype"
        static var po_Options           = "po_Options"
    }
}

extension UIView {
    
    fileprivate struct po_AssociatedKeys {
        static var po_ContentSize       = "po_ContentSize"
        static var po_Sender            = "po_Sender"
        static var po_Dialogtype        = "po_Dialogtype"
        static var po_Options           = "po_Options"
    }
}

extension UIView: Popoverable { }

extension UIViewController: Popoverable { }

extension UIViewController {
    
    func po_present(_ vc: UIViewController, tag: Int) {
        //判断重叠
        guard self.view.viewWithTag(tag) == nil else { return }
        let popover = Popover()
        vc.view.tag = tag
        popover.child = vc
        popover.parent = self
        popover.show()
    }
    
    func po_present(_ tv: UIView, tag: Int) {
        //判断重叠
        guard self.view.viewWithTag(tag) == nil else { return }
        let popover = Popover()
        tv.tag = tag
        popover.contentView = tv
        popover.parent = self
        popover.show()
    }
    
    func po_addchild(_ child: UIViewController, inview: UIView) {
        child.beginAppearanceTransition(true, animated: false)
        inview.addSubview(child.view)
        child.endAppearanceTransition()
        child.didMove(toParent: self)
        addChild(child)
    }
}
