//
//  TransactionTests.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/28/14.
//  Copyright (c) 2014 Uber Technologies Inc. All rights reserved.
//

import Foundation
import UIKit
import XCTest

class TransactionTests: XCTestCase {
    var root = TestModel()
    var child = TestModel()
    var scope = Scope(name: "Testing")
    var client = Client(transportAdapter: WebsocketTransportAdapter(options: WebsocketConnectionOptions(url: NSURL(string: "localhost")!)))
    var firstMessage: ScopeStateMessage!
    let uuid = NSUUID()
    
    override func setUp() {
        root = TestModel()
        child = TestModel()
        root.childModel = child
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
        scope.getAndClearSyncFragments()
 
        client = Client(transportAdapter: WebsocketTransportAdapter(options: WebsocketConnectionOptions(url: NSURL(string: "localhost")!)))
        var msg = SessionCreateReplyMessage(index: 1, sessionToken: "jeah", error: nil)
        client.receivedMessage(msg)
        client.session!.scopeAttach(scope, scopeIndex: 1)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAtomicChangeSetSuccessfulCompletion() {
        var didCall = false
        
        let changeSet = root.scope!.createAtomicChangeSet {
            self.root.int = 10
            self.root.float = 10.0
            self.root.string = "test"
        }.observeCompletion(self) { error in
            XCTAssertNil(error, "No error")
            didCall = true
        }
        
        var json: [String: AnyObject] = [
            "type": "ScopeSyncReply",
            "index": 2,
            "replyTo": 1,
            "fragmentReplies": [
                [String: AnyObject](),
            ]
        ]
        
        var reply = ScopeSyncReplyMessage.unserialize(json)
        client.transport.messageReceived(reply!)

        XCTAssertEqual(didCall, true, "Did invoke completion block")
        XCTAssertEqual(self.root.int, 10, "No rollback")
        XCTAssert(self.root.float == 10.0, "No rollback")
        XCTAssertEqual(self.root.string!, "test", "No rollback")
    }
    
    func testChangeSetSuccessfulCompletionWithModifications() {
        var didCall = false
        
        let changeSet = root.scope!.createAtomicChangeSet {
            self.root.int = 10
            self.root.float = 10.0
            self.root.string = "test"
            }.observeCompletion(self) { error in
                XCTAssertNil(error, "No error")
                didCall = true
        }
        
        var json: [String: AnyObject] = [
            "type": "ScopeSyncReply",
            "index": 2,
            "replyTo": 1,
            "fragmentReplies": [
                ["modifications": [
                    "int": 20,
                    "double": 20.0
                ]]
            ]
        ]
        
        var reply = ScopeSyncReplyMessage.unserialize(json)
        client.transport.messageReceived(reply!)
        
        XCTAssertEqual(didCall, true, "Did invoke completion block")
        XCTAssertEqual(self.root.int, 20, "Applied modification")
        XCTAssert(self.root.float == 10.0, "No rollback")
        XCTAssertEqual(self.root.string!, "test", "No rollback")
        XCTAssert(self.root.double == 20.0, "Applied modification")
    }
    
    func testAtomicFragmentReplyMismatch() {
        var didCall = false
        
        let changeSet = root.scope!.createAtomicChangeSet {
            self.root.int = 10
            self.root.float = 10.0
            self.root.string = "test"
            }.observeCompletion(self) { error in
                XCTAssertEqual(error!.localizedDescription, "Failed to apply change set", "Errored out")
                didCall = true
        }

        var json: [String: AnyObject] = [
            "type": "ScopeSyncReply",
            "index": 2,
            "replyTo": 1,
            "fragmentReplies": [[String: AnyObject]]()
        ]

        var reply = ScopeSyncReplyMessage.unserialize(json)
        client.transport.messageReceived(reply!)
        
        XCTAssertEqual(didCall, true, "Did invoke completion block")
        XCTAssertEqual(self.root.int, 0, "Did rollback")
        XCTAssert(self.root.float == 0.0, "Did rollback")
        XCTAssertNil(self.root.string, "Did rollback")
    }
    
    func testAtomicChangeInvalidMessageTypeError() {
        var didCall = false
        
        let changeSet = root.scope!.createAtomicChangeSet {
            self.root.int = 10
            self.root.float = 10.0
            self.root.string = "test"
        }.observeCompletion(self) { error in
            XCTAssertEqual(error!.localizedDescription, "Failed to apply change set", "Errored out")
            didCall = true
        }
        
        client.transport.messageReceived(ReplyMessage(index: 2, replyTo: 1))

        XCTAssertEqual(didCall, true, "Did invoke completion block")
        XCTAssertEqual(self.root.int, 0, "Did rollback")
        XCTAssert(self.root.float == 0.0, "Did rollback")
        XCTAssertNil(self.root.string, "Did rollback")
    }
    
    func testSpecificFragmentReversal() {
        var didCall = false
        
        let changeSet = root.scope!.createAtomicChangeSet {
            self.root.int = 20
            self.child.int = 20
            }.observeCompletion(self) { error in
                XCTAssertEqual(self.root.int, 0, "Kept change")
                XCTAssertEqual(self.child.int, 20, "Reverted change")
                didCall = true
        }
        
        var json: [String: AnyObject] = [
            "type": "ScopeSyncReply",
            "index": 2,
            "replyTo": 1,
            "fragmentReplies": [
                [String: AnyObject](),
                ["error": [
                    "code": 1,
                    "slug": "invalid-type",
                    "message": "Invalid type for property 'name'"
                    ]
                ]
            ]
        ]
        
        var reply = ScopeSyncReplyMessage.unserialize(json)
        client.transport.messageReceived(reply!)
        XCTAssertEqual(didCall, true, "Did invoke completion block")
    }
}
