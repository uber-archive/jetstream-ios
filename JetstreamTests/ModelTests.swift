//
//  ModelTests.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/10/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream


class ModelTests: XCTestCase {
    
    func testModelProperties() {
        var model = TestModel()
        
        var prop = model.properties["int"]
        XCTAssertEqual(prop!.key, "int" , "Property recognized")
        
        prop = model.properties["nonDynamicInt"]
        XCTAssert(prop == nil, "Non-dynamic property not recognized")
        
        prop = model.properties["nonDynamicString"]
        XCTAssert(prop == nil, "Non-dynamic property not recognized")
    }
}
