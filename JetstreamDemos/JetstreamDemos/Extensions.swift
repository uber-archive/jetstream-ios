//
//  Extensions.swift
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
import ObjectiveC

let loaderKey = UnsafePointer<Void>()

extension UIViewController {
    var host: String {
        get {
            var result: AnyObject? = NSBundle.mainBundle().infoDictionary!["JetstreamServer"]
            if let host = result as? String {
                return host
            } else {
                return "localhost"
            }
        }
    }
    
    func showLoader() {
        if loader != nil {
            hideLoader()
        }
        var size = UIScreen.mainScreen().bounds.size
        loader = UIView(frame: CGRectMake(0, 0, size.width, size.height))
        loader?.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.6)
        navigationController?.view.addSubview(loader!)
        
        let activityIndicatorView = UIActivityIndicatorView()
        loader?.addSubview(activityIndicatorView)
        activityIndicatorView.center = loader!.center
        activityIndicatorView.startAnimating()
    }
    
    func hideLoader() {
        if let view: UIView = loader {
            view.hidden = true
            view.removeFromSuperview()
            loader = nil
        }
    }
    
    func alertError(title: String, message: String) {
        hideLoader()
        
        let alert = UIAlertView(
            title: "Error",
            message: message,
            delegate: nil,
            cancelButtonTitle: "Ok")
        alert.show()
    }
    
    var loader: UIView? {
        get {
            if let definiteSelf: AnyObject! = self as AnyObject! {
                if let value = objc_getAssociatedObject(definiteSelf, loaderKey) as? UIView {
                    return value
                }
            }
            return nil
        }
        set(newValue) {
            if let definiteSelf: AnyObject! = self as AnyObject! {
                objc_setAssociatedObject(definiteSelf, loaderKey, newValue, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            }
        }
    }
}

extension UIColor {
    class func colorWithHexString(hex: String) -> UIColor {
        let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        var colorString: NSString = hex.stringByTrimmingCharactersInSet(whitespace).uppercaseString
        
        if colorString.hasPrefix("#") {
            colorString = colorString.substringFromIndex(1)
        }
        
        if colorString.length != 6 {
            return UIColor.grayColor()
        }
        
        var rString: NSString = colorString.substringToIndex(2)
        var gString: NSString = colorString.substringFromIndex(2)
        gString = gString.substringToIndex(2)
        var bString: NSString = colorString.substringFromIndex(4)
        bString = bString.substringToIndex(2)
        
        var r: CUnsignedInt = 0, g: CUnsignedInt = 0, b: CUnsignedInt = 0
        NSScanner(string: rString).scanHexInt(&r)
        NSScanner(string: gString).scanHexInt(&g)
        NSScanner(string: bString).scanHexInt(&b)
        
        var red = CGFloat(r) / 255.0
        var green = CGFloat(g) / 255.0
        var blue = CGFloat(b) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
