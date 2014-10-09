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
    
    func testSerializationFailure() {
        var uuid = NSUUID()
        
        var json: [String: AnyObject] = [
            "uuid": child.uuid.UUIDString
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Fragment with missing type shouldn't be created")
        
        json = [
            "type": "remove",
        ]
        fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Fragment with missing uuid shouldn't be created")
        
        json = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "parent": child.uuid.UUIDString,
            "properties": ["string": "set correctly"],
            "cls": "TestModel"
        ]
        fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Add fragment with missing keyPath property shouldn't be created")
        
        json = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "keyPath": "childModel",
            "parent": child.uuid.UUIDString,
            "properties": ["string": "set correctly"],
        ]
        fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Add fragment with missing cls property shouldn't be created")
        
        json = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "keyPath": "childModel",
            "properties": ["string": "set correctly"],
            "cls": "TestModel"
        ]
        fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Add fragment with missing parent property shouldn't be created")
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
    
    func testRoot() {
        var uuid = NSUUID()
        
        var json: [String: AnyObject] = [
            "type": "root",
            "uuid": uuid.UUIDString,
            "properties": ["string": "set correctly"],
            "cls": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.clsName!, "TestModel" , "Class name unserialized")
        
        fragment?.applyChangesToScope(scope)
        XCTAssert(parent.uuid == uuid , "UUID updated")
        XCTAssertEqual(parent.string!, "set correctly" , "Properties set correctly")
        XCTAssertEqual(scope.modelObjects.count, 2 , "Scope knows of added model")
    }
    
    func testAdd() {
        var uuid = NSUUID()

        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "parent": child.uuid.UUIDString,
            "keyPath": "childModel",
            "properties": ["string": "set correctly"],
            "cls": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.parentUUID!, child.uuid , "Parent UUID unserialized")
        XCTAssertEqual(fragment!.keyPath!, "childModel" , "Keypath unserialized")
        XCTAssertEqual(fragment!.clsName!, "TestModel" , "Class name unserialized")
        
        fragment?.applyChangesToScope(scope)
        var testModel = child.childModel!
        
        XCTAssertEqual(child.childModel!, testModel, "Child added")
        XCTAssertEqual(testModel.parent!.parent, child , "Child has correct parent")
        XCTAssert(testModel.scope === scope , "Scope set correctly")
        XCTAssertEqual(testModel.string!, "set correctly" , "Properties set correctly")
        XCTAssertEqual(scope.modelObjects.count, 3 , "Scope knows of added model")
    }
    
    func testAddToArray() {
        var uuid = NSUUID()
        
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "parent": child.uuid.UUIDString,
            "keyPath": "array",
            "properties": ["string": "set correctly"],
            "cls": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.parentUUID!, child.uuid , "Parent UUID unserialized")
        XCTAssertEqual(fragment!.keyPath!, "array" , "Keypath unserialized")
        XCTAssertEqual(fragment!.clsName!, "TestModel" , "Class name unserialized")
        
        fragment?.applyChangesToScope(scope)
        var testModel = child.array[0]
        
        XCTAssertEqual(child.array[0], testModel, "Child added")
        XCTAssertEqual(testModel.parent!.parent, child , "Child has correct parent")
        XCTAssert(testModel.scope === scope , "Scope set correctly")
        XCTAssertEqual(testModel.string!, "set correctly" , "Properties set correctly")
        XCTAssertEqual(scope.modelObjects.count, 3 , "Scope knows of added model")
    }
    
    func testChange() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": child.uuid.UUIDString,
            "properties": ["string": "testing"]
            
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.properties!.count, 1 , "Properties unserialized")
    }
    
    func testMoveChange() {
        var json: [String: AnyObject] = [
            "type": "movechange",
            "uuid": child.uuid.UUIDString,
            "parent": parent.uuid.UUIDString,
            "keyPath": "childModel2",
            "properties": ["string": "new value"]
            
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.parentUUID!, parent.uuid , "Parent UUID unserialized")
        XCTAssertEqual(fragment!.keyPath!, "childModel2" , "Keypath unserialized")
        
        fragment?.applyChangesToScope(scope)
        
        XCTAssertEqual(parent.childModel2!, child, "Child moved")
        XCTAssertEqual(child.parent!.parent, parent , "Child has correct parent")
        XCTAssert(child.scope === scope , "Scope set correctly")
        XCTAssertEqual(child.string!, "new value" , "Properties set correctly")
    }
}
