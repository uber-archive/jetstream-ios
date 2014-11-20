//
// SyncFragmentTests.swift
// Jetstream
// 
// Copyright (c) 2014 Uber Technologies, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import XCTest

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
            "properties": ["string": "set correctly"],
        ]
        fragment = SyncFragment.unserialize(json)
        XCTAssertNil(fragment , "Add fragment with missing cls property shouldn't be created")
    }
    
    func testChange() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": child.uuid.UUIDString,
            "properties": ["string": "testing", "int": 20]
            
        ]
        var fragment = SyncFragment.unserialize(json)
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.objectUUID, child.uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.properties!.count, 2 , "Properties unserialized")
        
        fragment?.applyChangesToScope(scope)
        XCTAssertEqual(parent.childModel!.string!, "testing" , "Properties applied")
        XCTAssertEqual(parent.childModel!.int, 20 , "Properties applied")
    }
    
    func testRemove() {
        var json = [
            "type": "remove",
            "uuid": child.uuid.UUIDString
        ]
        var fragment = SyncFragment.unserialize(json)
        
        
        fragment?.applyChangesToScope(scope)
        XCTAssertEqual(child.parents.count, 0, "Child removed")
        XCTAssert(parent.childModel == nil , "Parent's property set to nil")
    }
    
    func testRoot() {
        var uuid = NSUUID()
        
        var json: [String: AnyObject] = [
            "type": "root",
            "uuid": uuid.UUIDString,
            "properties": ["string": "set correctly"],
            "clsName": "TestModel"
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
            "properties": ["string": "set correctly"],
            "clsName": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        var json2: [String: AnyObject] = [
            "type": "change",
            "uuid": child.uuid.UUIDString,
            "properties": ["childModel": uuid.UUIDString],
        ]
        var fragment2 = SyncFragment.unserialize(json2)
        
        XCTAssertEqual(fragment!.objectUUID, uuid , "UUID unserialized")
        XCTAssertEqual(fragment!.clsName!, "TestModel" , "Class name unserialized")
        
        scope.applySyncFragments([fragment!, fragment2!])
        var testModel = child.childModel!
        
        XCTAssertEqual(child.childModel!, testModel, "Child added")
        XCTAssertEqual(testModel.parents[0].parent, child , "Child has correct parent")
        XCTAssert(testModel.scope === scope , "Scope set correctly")
        XCTAssertEqual(testModel.string!, "set correctly" , "Properties set correctly")
        XCTAssertEqual(scope.modelObjects.count, 3 , "Scope knows of added model")
    }
    
    func testAddToArray() {
        var uuid = NSUUID()
        
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": uuid.UUIDString,
            "properties": ["string": "set correctly"],
            "clsName": "TestModel"
        ]
        var fragment = SyncFragment.unserialize(json)
        var json2: [String: AnyObject] = [
            "type": "change",
            "uuid": child.uuid.UUIDString,
            "properties": ["array": [uuid.UUIDString]],
        ]
        var fragment2 = SyncFragment.unserialize(json2)

        scope.applySyncFragments([fragment!, fragment2!])
        var testModel = child.array[0]
        
        XCTAssertEqual(child.array[0], testModel, "Child added")
        XCTAssertEqual(testModel.parents[0].parent, child , "Child has correct parent")
        XCTAssert(testModel.scope === scope , "Scope set correctly")
        XCTAssertEqual(testModel.string!, "set correctly" , "Properties set correctly")
        XCTAssertEqual(scope.modelObjects.count, 3 , "Scope knows of added model")
    }
}
