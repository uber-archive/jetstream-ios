//
//  JetstreamTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import UIKit
import XCTest


class JetstreamTests: XCTestCase {
    
    func testGenericPropertyListeners() {
        var model = TestModel()
        var lastValue = ""
        
        model.onPropertyChange.listen(self, callback: {(keyPath, value) in
            if keyPath == "string" {
                lastValue = value as String
            }
        })
        
        model.string = "test"

        XCTAssertEqual(lastValue, "test" , "Value change captured")
    }
    
    func testSpecificPropertyListeners() {
        var model = TestModel()
        var dispatchCount = 0
        
        model.onChange(self, keyPath: "string") {
            dispatchCount += 1
        }

        model.string = "test"
        model.integer = 1
        model.float = 2.5
        
        XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        
        model.string = nil
        
        XCTAssertEqual(dispatchCount, 2 , "Dispatched twice")
    }
    
    func testMultiPropertyListeners() {
        var model = TestModel()
        var lastValue: NSString? = ""
        var dispatchCount = 0
        
        model.onChange(self, keyPaths: ["string", "integer"]) {
            dispatchCount += 1
        }
        
        model.string = "test"
        model.integer = 1
        model.float = 2.5
        
        XCTAssertEqual(dispatchCount, 2 , "Dispatched twice")
    }
}
