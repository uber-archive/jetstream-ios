//
//  ChangeSetQueueTests.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
        queue.addChangeSet(changeSet)
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
        queue.addChangeSet(changeSet)
        changeSet.revertOnScope(scope)
        
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
        queue.addChangeSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet2)
        
        changeSet.revertOnScope(scope)
        XCTAssertEqual(queue.count, 1, "Queue contains one change set")
        XCTAssertEqual(root.int, 3, "Change set reverted")
        XCTAssertEqual(root.float, Float(3.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 3", "Change set reverted")
        
        changeSet2.revertOnScope(scope)
        
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
        queue.addChangeSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet2)
        
        root.int = 4
        root.float = 4.0
        root.string = "test 4"
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet3)
        
        changeSet.revertOnScope(scope)
        changeSet2.revertOnScope(scope)
        changeSet3.revertOnScope(scope)
        
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
        queue.addChangeSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet2)
        
        root.int = 4
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet3)
        
        changeSet.revertOnScope(scope)
        changeSet2.revertOnScope(scope)
        changeSet3.revertOnScope(scope)
        
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
        queue.addChangeSet(changeSet)
        
        root.int = 3
        root.float = 3.0
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet2)
        
        changeSet.revertOnScope(scope)
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
        queue.addChangeSet(changeSet)
        
        root.int = 3
        root.string = "test 3"
        var changeSet2 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet2)
        
        root.int = 4
        root.float = 4.0
        root.string = "test 4"
        var changeSet3 = ChangeSet(syncFragments: scope.getAndClearSyncFragments(), atomic: false, scope: scope)
        queue.addChangeSet(changeSet3)
        
        changeSet.revertOnScope(scope)
        changeSet2.revertOnScope(scope)
        changeSet3.revertOnScope(scope)
        
        XCTAssertEqual(root.int, 1, "Change set reverted")
        XCTAssertEqual(root.float, Float(1.0), "Change set reverted")
        XCTAssertEqual(root.string!, "test 1", "Change set reverted")
        XCTAssertEqual(queue.count, 0, "Queue empty")
    }
}
