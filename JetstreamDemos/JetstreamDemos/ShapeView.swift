//
//  ShapeView.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
