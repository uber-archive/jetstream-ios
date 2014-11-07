//
//  Functions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
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

func error(code: ErrorCode, localizedDescription: String? = nil) -> NSError {
    var userInfo: [NSObject: AnyObject]?
    if let definiteLocalizedDescription = localizedDescription {
        userInfo = [NSLocalizedDescriptionKey: definiteLocalizedDescription]
    }
    return NSError(
        domain: defaultErrorDomain,
        code: code.rawValue,
        userInfo: userInfo)
}

func errorWithUserInfo(code: ErrorCode, userInfo: [NSObject: AnyObject]) -> NSError {
    return NSError(
        domain: defaultErrorDomain,
        code: code.rawValue,
        userInfo: userInfo)
}

func errorFromDictionary(code: ErrorCode, error: [NSString: AnyObject]) -> NSError {
    var userInfo = [NSLocalizedDescriptionKey: "Unknown error"]
    if let errorMessage = error["message"] as? String {
        userInfo[NSLocalizedDescriptionKey] = errorMessage
    }
    if let errorSlug = error["slug"] as? String {
        userInfo[NSLocalizedFailureReasonErrorKey] = errorSlug
    }
    return errorWithUserInfo(code, userInfo)
}
