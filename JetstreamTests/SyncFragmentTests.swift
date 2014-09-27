//
//  SyncFragmentTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream


class SyncFragmentTests: XCTestCase {
    
    var parent = TestModel()
    var child = TestModel()
    var scope = Scope(name: "Testing")

    override func setUp() {
        parent = TestModel()
        child = TestModel()
        parent.childModel = child
        scope = Scope(name: "Testing")
        parent.setScopeAndMakeRootModel(scope)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRemove() {
        var json = [
            "type": "remove",
            "uuid": child.uuid.UUIDString
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        
        fragment?.applyChangesToScope(scope)
        XCTAssert(child.parent == nil , "Child removed")
        XCTAssert(parent.childModel == nil , "Parent's property set to nil")
    }
    
    func testAdd() {
        
        var uuid = NSUUID()
        var json = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "parent": child.uuid.UUIDString,
            "keyPath": "childModel",
            "cls": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.parentUUID!, parent.uuid , "Parent UUID unserialized")
        XCTAssertEqual(fragment!.keyPath!, "childModel" , "Keypath unserialized")
        XCTAssertEqual(fragment!.clsName!, "TestModel" , "Class name unserialized")
        
        fragment?.applyChangesToScope(scope)
        var testModel = child.childModel!
        
        XCTAssertEqual(child.childModel!, testModel, "Child added")
        XCTAssertEqual(testModel.parent!.parent, child , "Child has correct parent")
    }
    
    func testChange() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": child.uuid.UUIDString,
            "properties": ["string": "testing"]
            
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.properties.count, 1 , "Properties unserialized")
    }
    
}
