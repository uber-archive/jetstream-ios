//
//  JetstreamViewController.swift
//  JetstreamDemos
//
//  Created by Rob Skillington on 10/13/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

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
