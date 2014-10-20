//
//  TestHelpers.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/17/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import XCTest

public func delayTest(test: XCTestCase, delay: Double, callback: () -> ()) {
    let expectation = test.expectationWithDescription("testDelay")
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
        callback()
        expectation.fulfill()
    }
    test.waitForExpectationsWithTimeout(delay + 2.0, handler: nil)
}