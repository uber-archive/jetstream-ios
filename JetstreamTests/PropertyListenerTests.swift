//
//  PropertyListenerTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream


class PropertyListenerTests: XCTestCase {
    
    func testGenericPropertyListeners() {
        var model = TestModel()
        var lastValue = ""
        
        model.onPropertyChange.listen(self, callback: {(keyPath, oldValue, value) in
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
        
        model.observeChange(self, keyPath: "string") {
            dispatchCount += 1
        }

        model.string = "test"
        model.int = 1
        model.float = 2.5
        
        XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        
        model.string = nil
        
        XCTAssertEqual(dispatchCount, 2 , "Dispatched twice")
    }
    
    func testMultiPropertyListeners() {
        var model = TestModel()
        var lastValue: NSString? = ""
        var dispatchCount = 0
        
        model.observeChange(self, keyPaths: ["string", "int"]) {
            dispatchCount += 1
        }
        
        model.string = "test"
        model.int = 1
        model.float = 2.5
        
        XCTAssertEqual(dispatchCount, 2 , "Dispatched twice")
    }
    
    func testNoDispatchForNoChange() {
        var model = TestModel()
        var lastValue: NSString? = ""
        var dispatchCount = 0
        
        model.observeChange(self) {
            dispatchCount += 1
        }
        XCTAssertEqual(dispatchCount, 0 , "Dispatched once")
        
        model.int = 10
        model.int = 10
        XCTAssertEqual(dispatchCount, 1 , "Dispatched once")
        
        model.uint = 10
        model.uint = 10
        XCTAssertEqual(dispatchCount, 2 , "Dispatched once")
        
        model.uint8 = 10
        model.uint8 = 10
        XCTAssertEqual(dispatchCount, 3 , "Dispatched once")
        
        model.int8 = 10
        model.int8 = 10
        XCTAssertEqual(dispatchCount, 4 , "Dispatched once")
        
        model.uint16 = 10
        model.uint16 = 10
        XCTAssertEqual(dispatchCount, 5 , "Dispatched once")
        
        model.int16 = 10
        model.int16 = 10
        XCTAssertEqual(dispatchCount, 6 , "Dispatched once")
        
        model.uint32 = 10
        model.uint32 = 10
        XCTAssertEqual(dispatchCount, 7 , "Dispatched once")
        
        model.int32 = 10
        model.int32 = 10
        XCTAssertEqual(dispatchCount, 8 , "Dispatched once")
        
        model.uint64 = 10
        model.uint64 = 10
        XCTAssertEqual(dispatchCount, 9 , "Dispatched once")
        
        model.int64 = 10
        model.int64 = 10
        XCTAssertEqual(dispatchCount, 10 , "Dispatched once")
        
        model.bool = true
        model.bool = true
        XCTAssertEqual(dispatchCount, 11 , "Dispatched once")
        
        model.string = "test"
        model.string = "test"
        XCTAssertEqual(dispatchCount, 12 , "Dispatched once")
        
        model.string = "test 2"
        model.string = "test 2"
        XCTAssertEqual(dispatchCount, 13 , "Dispatched once")
        
        model.float = 10.0
        model.float = 10.0
        XCTAssertEqual(dispatchCount, 15 , "Dispatched twice") // float is part of composite property
        
        model.float = 10.1
        model.float = 10.2
        XCTAssertEqual(dispatchCount, 19 , "Dispatched four times") // float is part of composite property
        
        
        model.double = 10.0
        model.double = 10.0
        XCTAssertEqual(dispatchCount, 20 , "Dispatched once")
        
        model.double = 10.1
        model.double = 10.2
        XCTAssertEqual(dispatchCount, 22 , "Dispatched twice")
        
        model.testType = .Active
        model.testType = .Active
        XCTAssertEqual(dispatchCount, 23 , "Dispatched once")
    }

    func testArrayListeners() {
        var model = TestModel()
        var changedCount = 0
        var addedCount = 0
        var removedCount = 0
        
        model.observeChange(self, keyPath: "array") {
            changedCount += 1
        }
        model.observeCollectionAdd(self, keyPath: "array") { (element: ModelObject) -> Void in
            addedCount += 1
        }
        
        model.observeCollectionRemove(self, keyPath: "array") { (element: ModelObject) -> Void in
            removedCount += 1
        }
        
        model.array.append(TestModel())
        model.array[0] = TestModel()
        model.array.removeLast()
        model.array = [TestModel()]

        XCTAssertEqual(changedCount, 4 , "Dispatched four times")
        XCTAssertEqual(addedCount, 3 , "Dispatched three times")
        XCTAssertEqual(removedCount, 2 , "Dispatched two times")
        
        model.array[0].detach()
        XCTAssertEqual(removedCount, 3 , "Dispatched three times")
        
    }

}
