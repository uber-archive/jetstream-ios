//
//  ChangeSetTests.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/20/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import UIKit
import XCTest

class ChangeSetTests: XCTestCase {
    var root = TestModel()
    var child = TestModel()
    var scope = Scope(name: "Testing")
    
    override func setUp() {
        root = TestModel()
        child = TestModel()
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBasicReversal() {
        root.int = 10
        root.float = 10.0
        root.string = "test"
        scope.getAndClearSyncFragments()
        
        root.int = 20
        root.float = 20.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        changeSet.revert(scope)
        
        XCTAssertEqual(root.int, 10, "Change set reverted")
        XCTAssertEqual(root.float, Float(10.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test", "Change set reverted")
    }
    
    func testModelReversal() {
        root.childModel = child
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        
        changeSet.revert(scope)
        
        XCTAssert(root.childModel == nil, "Change set reverted")
        XCTAssertEqual(scope.modelObjects.count, 1 , "Scope knows correct models")
    }
    
    func testModelReapplying() {
        root.childModel = child
        scope.getAndClearSyncFragments()
        
        root.childModel = nil
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        
        changeSet.revert(scope)
        
        XCTAssert(root.childModel == child, "Change set reverted")
        XCTAssertEqual(scope.modelObjects.count, 2 , "Scope knows correct models")
    }
}
