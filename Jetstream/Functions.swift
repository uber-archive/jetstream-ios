//
//  Functions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public func delay(delay: Double, callback: () -> ()) {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))),
        dispatch_get_main_queue(),
        callback)
}

public func asyncMain(callback: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), callback)
}
