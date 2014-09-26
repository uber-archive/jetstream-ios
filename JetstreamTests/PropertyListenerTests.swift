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
        
        model.observeChange(self, keyPath: "string") {
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
        
        model.observeChange(self, keyPaths: ["string", "integer"]) {
            dispatchCount += 1
        }
        
        model.string = "test"
        model.integer = 1
        model.float = 2.5
        
        XCTAssertEqual(dispatchCount, 2 , "Dispatched twice")
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

        XCTAssertEqual(changedCount, 0 , "Dispatched zero times")
        XCTAssertEqual(addedCount, 3 , "Dispatched three times")
        XCTAssertEqual(removedCount, 2 , "Dispatched three times")
    }
}
