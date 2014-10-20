//
//  PropertyListenerTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 10/17/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream

class ImmediatePropertyListenerTests: XCTestCase {
    
    func testSpecificPropertyListeners() {
        var model = TestModel()
        var dispatchCount = 0
        
        model.observeChange(self, key: "string") {
            dispatchCount += 1
        }
        
        model.string = "test"
        model.string = "test 2"
        model.int = 1
        model.float = 2.5
        
        delayTest(self, 0.01) {
            XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        }
    }
    
    func testMultiPropertyListeners() {
        var model = TestModel()
        var lastValue: NSString? = ""
        var dispatchCount = 0
        
        model.observeChange(self, keys: ["string", "int"]) {
            dispatchCount += 1
        }
        
        model.string = "test"
        model.int = 1
        model.string = "test"
        model.int = 1
        model.float = 2.5
        
        delayTest(self, 0.01) {
            XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        }
    }
    
    func testNoDispatchForNoChange() {
        var model = TestModel()
        var lastValue: NSString? = ""
        var dispatchCount = 0
        
        model.observeChange(self) {
            dispatchCount += 1
        }
    
        model.int = 10
        model.int = 10
        
        model.uint = 10
        model.uint = 10
        
        model.uint8 = 10
        model.uint8 = 10
        
        model.int8 = 10
        model.int8 = 10
        
        model.uint16 = 10
        model.uint16 = 10
        
        model.int16 = 10
        model.int16 = 10
        
        model.uint32 = 10
        model.uint32 = 10
  
        model.int32 = 10
        model.int32 = 10

        model.uint64 = 10
        model.uint64 = 10
   
        model.int64 = 10
        model.int64 = 10
   
        model.bool = true
        model.bool = true
 
        model.string = "test"
        model.string = "test"
     
        model.string = "test 2"
        model.string = "test 2"
 
        model.float = 10.0
        model.float = 10.0
 
        model.float = 10.1
        model.float = 10.2
  
        model.double = 10.0
        model.double = 10.0
   
        model.double = 10.1
        model.double = 10.2
    
        model.testType = .Active
        model.testType = .Active
        
        delayTest(self, 0.01) {
            XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        }
    }
}
