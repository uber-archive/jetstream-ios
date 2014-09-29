//
//  ScopeTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream


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
    
    func testScopeFragmentCount() {
        parent.setScopeAndMakeRootModel(scope)
        var fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 0 , "Adding root model shouldn't change scope")
        
        parent.childModel = child
        child.childModel = child2
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 2 , "Correct amount of fragments")
        XCTAssertEqual(fragments[0].type, SyncFragmentType.Add , "Correct fragment type")
        XCTAssertEqual(fragments[1].type, SyncFragmentType.Add , "Correct fragment type")
        
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 0 , "Fragments cleared out after getting")
        
        child.string = "Testing"
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 1 , "Correct amount of fragments")
        XCTAssertEqual(fragments[0].type, SyncFragmentType.Change , "Correct fragment type")
        
        parent.childModel = nil
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 2 , "Child removals captured")
        XCTAssertEqual(fragments[0].type, SyncFragmentType.Remove , "Correct fragment type")
        XCTAssertEqual(fragments[1].type, SyncFragmentType.Remove , "Correct fragment type")
        
        child.string = "Testing more"
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 0 , "Removed object no longer listened to")
    }
    
    func testScopeFragmentCountWhenAddingAndChanging() {
        parent.setScopeAndMakeRootModel(scope)
        parent.childModel = child
        child.childModel = child2
        
        parent.string = "testing more"
        child.string = "testing more"
        
        var fragments = scope.getAndClearSyncFragments()
        
        XCTAssertEqual(fragments.count, 3 , "Changes don't create fragments when object have been added")
    }
    
    func testScopeFragmentListening() {
        let expectation = expectationWithDescription("onChange")
        parent.setScopeAndMakeRootModel(scope)
        scope.getAndClearSyncFragments()
        
        scope.onChanges.listen(self, callback: { (fragments) -> Void in
            XCTAssertEqual(fragments.count, 3, "Changes don't create fragments when object have been added")
            
            var fragment = fragments[0]
            XCTAssertEqual(fragment.type, SyncFragmentType.Add, "Fragment is correct")
            XCTAssertEqual(fragment.objectUUID, self.child.uuid, "Fragment is correct")
            XCTAssertEqual(fragment.parentUUID!, self.parent.uuid, "Fragment is correct")
            XCTAssertEqual(fragment.keyPath!, "childModel", "Fragment is correct")
            
            fragment = fragments[1]
            XCTAssertEqual(fragment.type, SyncFragmentType.Add, "Fragment is correct")
            XCTAssertEqual(fragment.objectUUID, self.child2.uuid, "Fragment is correct")
            XCTAssertEqual(fragment.parentUUID!, self.child.uuid, "Fragment is correct")
            XCTAssertEqual(fragment.keyPath!, "childModel2", "Fragment is correct")
            
            fragment = fragments[2]
            XCTAssertEqual(fragment.type, SyncFragmentType.Change, "Fragment is correct")
            XCTAssertEqual(fragment.objectUUID, self.parent.uuid, "Fragment is correct")
            XCTAssertEqual(fragment.properties!.count, 1, "Fragment is correct")

            expectation.fulfill()
        })
        
        parent.childModel = child
        child.childModel2 = child2
        parent.string = "testing more"
        child.string = "testing more"

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSubsequentRemoval() {
        parent.setScopeAndMakeRootModel(scope)
        var fragments = scope.getAndClearSyncFragments()
  
        parent.childModel = child
        parent.childModel = nil
        fragments = scope.getAndClearSyncFragments()
        XCTAssertEqual(fragments.count, 0 , "Correct amount of fragments")
    }
}
