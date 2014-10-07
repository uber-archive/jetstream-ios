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

    
    override func setUp() {
        root = TestModel()
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testApplying() {
        
        let uuid = NSUUID()
        
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
            "syncFragments": []
        ]
        
        
        let message = Message.unserialize(json) as ScopeStateMessage
        XCTAssertEqual(message.index, 1, "Message unserialized")
        XCTAssertEqual(message.scopeIndex, 1, "Message unserialized")
        XCTAssertEqual(message.rootFragment.type, SyncFragmentType.Root, "Message unserialized")
        XCTAssertEqual(message.syncFragments.count, 0, "Message unserialized")
    }
}
