//
//  ShapeView.swift
//  JetstreamDemos
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import UIKit

public class ShapeView: UIView, UIGestureRecognizerDelegate {
    var shape: Shape = Shape() {
        willSet {
            shape.removeObservers(self)
        }
        didSet {
            shape.observeChange(self, keys: ["x", "y", "width", "height"]) { [weak self] in
                if let this = self {
                    this.updateView()
                }
            }
            shape.observeDetach(self) { [weak self] (scope) in
                if let this = self {
                    this.removeFromSuperview()
                }
            }
            updateView()
        }
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(shape: Shape) {
        super.init(frame: CGRectZero)
        backgroundColor = shape.color
        layer.cornerRadius = 5
        let panRecognizer = UIPanGestureRecognizer(target: self, action: Selector("handlePan:"))
        self.addGestureRecognizer(panRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleTap:"))
        self.addGestureRecognizer(tapRecognizer)
        setShape(shape)
    }
    
    private func setShape(shape: Shape) {
        self.shape = shape
    }
    
    dynamic public func handlePan(recognizer:UIPanGestureRecognizer) {
        let translation = recognizer.translationInView(self)
        recognizer.setTranslation(CGPointZero, inView: self)
        
        shape.x += translation.x
        shape.y += translation.y
    }
    
    dynamic public func handleTap(recognizer:UITapGestureRecognizer) {
        shape.detach()
    }
    
    func updateView() {
        self.frame = CGRect(
            x: CGFloat(shape.x),
            y: CGFloat(shape.y),
            width: CGFloat(shape.width),
            height: CGFloat(shape.height))
    }
}
