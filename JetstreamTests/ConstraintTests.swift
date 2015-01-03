//
//  ConstraintTests.swift
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
import Jetstream

class ConstraintTests: XCTestCase {
    func testMultipleMatching() {
        var json: [[String: AnyObject]] = [
            [
                "type": "add",
                "uuid": NSUUID().UUIDString,
                "clsName": "TestModel",
                "properties": ["string": "set correctly"]
            ],
            [
                "type": "add",
                "uuid": NSUUID().UUIDString,
                "clsName": "AnotherTestModel",
                "properties": ["anotherString": "set correctly"]
            ],
            [
                "type": "change",
                "uuid": NSUUID().UUIDString,
                "clsName": "TestModel",
                "properties": ["int": 3]
            ]
        ]
        var fragments = json.map { SyncFragment.unserialize($0)! }
        
        
        var constraints1: [String: AnyObject] = [
            "string": "set correctly"
        ]
        var constraints2: [String: AnyObject] = [
            "anotherString": "set correctly"
        ]
        var constraints3: [String: AnyObject] = [
            "int": 3
        ]
        var constraints = [
            Constraint(type: .Add, clsName: "TestModel", properties: constraints1, allowAdditionalProperties: false),
            Constraint(type: .Add, clsName: "AnotherTestModel", properties: constraints2, allowAdditionalProperties: false),
            Constraint(type: .Change, clsName: "TestModel", properties: constraints3, allowAdditionalProperties: false),
        ]
        
        XCTAssertTrue(Constraint.matchesAll(constraints, syncFragments: fragments), "Constraint should match fragment")
    }
    
    func testSimpleAddMatching() {
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly"]
        ]
        var fragment = SyncFragment.unserialize(json)
        
        let constraint = Constraint(type: .Add, clsName: "TestModel")
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleAddWithPropertiesMatching() {
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly"]
        ]
        var fragment = SyncFragment.unserialize(json)
        
        let constraint = Constraint(type: .Add, clsName: "TestModel", properties: ["string": "set correctly"], allowAdditionalProperties: false)
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleAddWithPropertiesMatchingWithBadAdditionalProperties() {
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "int": 3]
        ]
        var fragment = SyncFragment.unserialize(json)
        
        let constraint = Constraint(type: .Add, clsName: "TestModel", properties: ["string": "set correctly"], allowAdditionalProperties: false)
        XCTAssertFalse(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleAddWithPropertiesMatchingWithAllowedAdditionalProperties() {
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "int": 3]
        ]
        var fragment = SyncFragment.unserialize(json)
        
        let constraint = Constraint(type: .Add, clsName: "TestModel", properties: ["string": "set correctly"], allowAdditionalProperties: true)
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleAddWithArrayInsertPropertyMatching() {
        var json: [String: AnyObject] = [
            "type": "add",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "array": [NSUUID().UUIDString]]
        ]
        var fragment = SyncFragment.unserialize(json)
        
        let constraint = Constraint(type: .Add, clsName: "TestModel", properties: [
            "string": "set correctly",
            "array": ArrayConstraintOperation(type: .Insert)
        ], allowAdditionalProperties: false)
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleChangeWithArrayInsertPropertyMatching() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "array": [NSUUID().UUIDString]]
        ]
        var fragment = SyncFragment.unserialize(json)
        fragment!.originalProperties = [
            "array": []
        ]
        
        let constraint = Constraint(type: .Change, clsName: "TestModel", properties: [
            "string": "set correctly",
            "array": ArrayConstraintOperation(type: .Insert)
            ], allowAdditionalProperties: false)
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleChangeWithArrayInsertPropertyNotMatching() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "array": [NSUUID().UUIDString]]
        ]
        var fragment = SyncFragment.unserialize(json)
        fragment!.originalProperties = [
            "array": [NSUUID().UUIDString]
        ]
        
        let constraint = Constraint(type: .Change, clsName: "TestModel", properties: [
            "string": "set correctly",
            "array": ArrayConstraintOperation(type: .Insert)
            ], allowAdditionalProperties: false)
        XCTAssertFalse(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleChangeWithArrayRemovePropertyMatching() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "array": []]
        ]
        var fragment = SyncFragment.unserialize(json)
        fragment!.originalProperties = [
            "array": [NSUUID().UUIDString]
        ]
        
        let constraint = Constraint(type: .Change, clsName: "TestModel", properties: [
            "string": "set correctly",
            "array": ArrayConstraintOperation(type: .Remove)
        ], allowAdditionalProperties: false)
        XCTAssertTrue(constraint.matches(fragment!), "Constraint should match fragment")
    }
    
    func testSimpleChangeWithArrayRemovePropertyNotMatching() {
        var json: [String: AnyObject] = [
            "type": "change",
            "uuid": NSUUID().UUIDString,
            "clsName": "TestModel",
            "properties": ["string": "set correctly", "array": [NSUUID().UUIDString]]
        ]
        var fragment = SyncFragment.unserialize(json)
        fragment!.originalProperties = [
            "array": [NSUUID().UUIDString]
        ]
        
        let constraint = Constraint(type: .Change, clsName: "TestModel", properties: [
            "string": "set correctly",
            "array": ArrayConstraintOperation(type: .Remove)
        ], allowAdditionalProperties: false)
        XCTAssertFalse(constraint.matches(fragment!), "Constraint should match fragment")
    }
}
