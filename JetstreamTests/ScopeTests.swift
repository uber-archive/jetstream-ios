//
//  JetstreamTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest


class ScopeTests: XCTestCase {
    
    var parent = TestModel()
    var child = TestModel()
    var child2 = TestModel()
    var child3 = TestModel()
    var scope = Scope(name: "Testing")
    

    
    override func setUp() {
        parent = TestModel()
        child = TestModel()
        child2 = TestModel()
        child3 = TestModel()
        scope = Scope(name: "Testing")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAutomaticScopeCreation() {
        parent.isScopeRoot = true
        scope = parent.scope!
        XCTAssertEqual(scope.modelObjects.count, 1 , "Correct amount of models in scope")
        parent.childModel = child
        XCTAssertEqual(scope.modelObjects.count, 2 , "Correct amount of models in scope")
        
        parent.childModel = child2
        XCTAssertEqual(scope.modelObjects.count, 2 , "Correct amount of models in scope")
        
        parent.childModel = child3
        XCTAssertEqual(scope.modelObjects.count, 2 , "Correct amount of models in scope")

        parent.isScopeRoot = false
        XCTAssertEqual(scope.modelObjects.count, 0 , "Correct amount of models in scope")
    }
    
    func testAutomaticLateScopeCreation() {
        parent.childModel = child
        child.childModel = child2
        child.childModel2 = child2
        child2.childModel = child3
        
        parent.isScopeRoot = true
        var scope = parent.scope!
        
        XCTAssertEqual(scope.modelObjects.count, 4 , "Correct amount of models in scope")
        
        parent.isScopeRoot = false
        XCTAssertEqual(scope.modelObjects.count, 0 , "Correct amount of models in scope")
    }
    
    func testScope() {
        parent.setScopeAndMakeRootModel(scope)
        parent.childModel = child
        
        XCTAssertEqual(scope.modelObjects.count, 2 , "Correct amount of models in scope")
    }
}
