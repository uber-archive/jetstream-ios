//
//  MessageSerialization.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit
import XCTest
import Jetstream


class StateMessageTests: XCTestCase {
    
    var root = TestModel()
    var scope = Scope(name: "Testing")
    var client = Client(options: ConnectionOptions(url: "localhost"))
    var firstMessage: ScopeStateMessage!
    let uuid = NSUUID()

    override func setUp() {
        root = TestModel()
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
        client = Client(options: ConnectionOptions(url: "localhost"))
        client.attachScope(scope)
        
        let childUUID = NSUUID()
        
        var json = [
            "type": "ScopeState",
            "index": 1,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": ["string": "set correctly"],
                "cls": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": childUUID.UUIDString,
                    "parent": uuid.UUIDString,
                    "keyPath": "childModel",
                    "properties": ["string": "ok"],
                    "cls": "TestModel"
                ]
            ]
        ]
        
        firstMessage = Message.unserialize(json) as ScopeStateMessage
        client.receivedMessage(firstMessage)
        
        XCTAssertEqual(root.uuid, uuid, "Message applied")
        XCTAssertEqual(root.string!, "set correctly", "Message applied")
        XCTAssertEqual(root.childModel!.uuid, childUUID, "Message applied")
        XCTAssertEqual(root.childModel!.string!, "ok", "Message applied")
        XCTAssertEqual(scope.modelObjects.count, 2, "Correct number of objects in scope")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testReaplying() {
        root.observeChange(self, callback: { () -> Void in
            XCTFail("Should not observe changes")
        })
        
        client.receivedMessage(firstMessage)
        
        XCTAssertEqual(root.uuid, firstMessage.rootFragment.objectUUID, "Message applied")
        XCTAssertEqual(root.string!, "set correctly", "Message applied")
        XCTAssertEqual(root.childModel!.string!, "ok", "Message applied")
        XCTAssertEqual(scope.modelObjects.count, 2, "Correct number of objects in scope")
    }
    
    func testReapplyingRemoval() {
  
        let childUUID = NSUUID()
        
        var json = [
            "type": "ScopeState",
            "index": 1,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": ["string": "set correctly"],
                "cls": "TestModel"
            ],
            "fragments": []
        ]

        client.receivedMessage(Message.unserialize(json)!)

        XCTAssertNil(root.childModel, "Removed child")
        XCTAssertEqual(scope.modelObjects.count, 1, "Correct number of objects in scope")
    }
    
    func testReapplyingMoving() {
        
        var json = [
            "type": "ScopeState",
            "index": 1,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": ["string": "set correctly"],
                "cls": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": root.childModel!.uuid.UUIDString,
                    "parent": uuid.UUIDString,
                    "keyPath": "childModel2",
                    "properties": ["string": "ok"],
                    "cls": "TestModel"
                ]
            ]
        ]
        
        XCTAssert(root.childModel != nil, "Child model moved")
        
        var observeCount = 0
        root.childModel?.observeMove(self, callback: { () -> Void in
            observeCount += 1
        })
        
        client.receivedMessage(Message.unserialize(json)!)
        
        XCTAssertEqual(observeCount, 1, "Observed move")
        XCTAssert(root.childModel == nil, "Child model moved")
        XCTAssert(root.childModel2 != nil, "Child model moved")
        XCTAssertEqual(scope.modelObjects.count, 2, "Correct number of objects in scope")
    }
    
    func testAddingDependentFirst() {
        let childUUID = NSUUID()
        let childUUID2 = NSUUID()
        
        var json = [
            "type": "ScopeState",
            "index": 1,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": ["string": "set correctly"],
                "cls": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": childUUID2.UUIDString,
                    "parent": childUUID.UUIDString,
                    "keyPath": "childModel",
                    "properties": ["string": "ok2"],
                    "cls": "TestModel"
                ],
                [
                    "type": "add",
                    "uuid": childUUID.UUIDString,
                    "parent": uuid.UUIDString,
                    "keyPath": "childModel2",
                    "properties": ["string": "ok1"],
                    "cls": "TestModel"
                ]
            ]
        ]
        
        client.receivedMessage(Message.unserialize(json)!)
        
        XCTAssertEqual(root.childModel2!.uuid, childUUID, "Child model added")
        XCTAssertEqual(root.childModel2!.childModel!.uuid, childUUID2, "Child model added")
        XCTAssertEqual(scope.modelObjects.count, 3, "Correct number of objects in scope")
    }
}
