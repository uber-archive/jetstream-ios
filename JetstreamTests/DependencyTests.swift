//
//  DependcyTests.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/1/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import XCTest

class DependencyTests: XCTestCase {
    var testModel = TestModel()
    var anotherTestModel = AnotherTestModel()
    
    override func setUp() {
        testModel = TestModel()
        anotherTestModel = AnotherTestModel()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testDependentListeners() {
        var fireCount1 = 0
        var fireCount2 = 0
        
        testModel.observeChangeImmediately(self, key: "compositeProperty") { () -> Void in
            fireCount1 += 1
        }
        
        anotherTestModel.observeChangeImmediately(self, key: "anotherCompositeProperty") { () -> Void in
            fireCount2 += 1
        }
        
        testModel.float = 2.0
        testModel.float = 3.0
        testModel.anotherArray = [anotherTestModel]
        
        XCTAssertEqual(fireCount1, 3, "Dispatched three times")
        XCTAssertEqual(fireCount2, 0, "Not dispatched")
        
        anotherTestModel.anotherString = "kiva"
        anotherTestModel.anotherInteger = 1
        
        XCTAssertEqual(fireCount1, 3, "Dispatched three times")
        XCTAssertEqual(fireCount2, 2, "Dispatched twice")
    }
}
