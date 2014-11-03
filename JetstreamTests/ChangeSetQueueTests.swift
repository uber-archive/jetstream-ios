//
//  ChangeSetQueueTests.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/22/14.
//  Copyright (c) 2014 Uber Technologies Inc. All rights reserved.
//

import Foundation
import UIKit
import XCTest

class ChangeSetQueueTests: XCTestCase {
    var root = TestModel()
    var child = TestModel()
    var scope = Scope(name: "Testing")
    var queue = ChangeSetQueue()
    
    override func setUp() {
        root = TestModel()
        child = TestModel()
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCompleting() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        changeSet.completed()
        
        XCTAssertEqual(root.int, 2, "Change set not reverted")
        XCTAssertEqual(root.float, Float(2.0), "Change set not reverted")
        XCTAssertEqual(root.string!, "test 2", "Change set not reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testReverting() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        changeSet.revert(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testRebasing() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet2)
        
        changeSet.revert(scope)
        XCTAssertEqual(queue.count, 1, "Queue contains one change set")
        XCTAssertEqual(root.int, 3, "Change set reverted")
        XCTAssertEqual(root.float, Float(3.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 3", "Change set reverted")
        
        changeSet2.revert(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testSubsetRebasing() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet2)
        
        root.int = 4
        root.float = 4.0
        root.string = "test 4"
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet3)
        
        changeSet.revert(scope)
        changeSet2.revert(scope)
        changeSet3.revert(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testSupersetRebasing() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet2)
        
        root.int = 4
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet3)
        
        changeSet.revert(scope)
        changeSet2.revert(scope)
        changeSet3.revert(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testReverseInBetweenChangeSet() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet2)
        
        changeSet.revert(scope)
        changeSet2.completed()
        
        XCTAssertEqual(root.int, 3, "Change set reverted")
        XCTAssertEqual(root.float, Float(3.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 3", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
    
    func testRebasingOverChangeSets() {
        root.int = 1
        root.float = 1.0
        root.string = "test 1"
        scope.getAndClearSyncFragments()
        
        root.int = 2
        root.float = 2.0
        root.string = "test 2"
        var changeSet = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet)
        
        root.int = 3
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet2)
        
        root.int = 4
        root.float = 4.0
        root.string = "test 4"
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChageSet(changeSet3)
        
        changeSet.revert(scope)
        changeSet2.revert(scope)
        changeSet3.revert(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
}
