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
    var client = Client(transportAdapter: WebsocketTransportAdapter(options: WebsocketConnectionOptions(url: NSURL(string: "localhost")!)))
    var firstMessage: ScopeStateMessage!
    let uuid = NSUUID()

    override func setUp() {
        root = TestModel()
        scope = Scope(name: "Testing")
        root.setScopeAndMakeRootModel(scope)
        XCTAssertEqual(scope.modelObjects.count, 1, "Correct number of objects in scope to start with")
        
        client = Client(transportAdapter: WebsocketTransportAdapter(options: WebsocketConnectionOptions(url: NSURL(string: "localhost")!)))
        var msg = SessionCreateResponseMessage(index: 1, success: true, sessionToken: "jeah", response: nil)
        client.receivedMessage(msg)
        client.session!.scopeAttach(scope, scopeIndex: 1)

        
        let childUUID = NSUUID()
        
        var json = [
            "type": "ScopeState",
            "index": 1,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": [
                    "string": "set correctly",
                    "childModel": childUUID.UUIDString
                ],
                "clsName": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": childUUID.UUIDString,
                    "properties": ["string": "ok"],
                    "clsName": "TestModel"
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
            "index": 2,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": ["string": "set correctly"],
                "clsName": "TestModel"
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
            "index": 2,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": [
                    "string": "set correctly",
                    "childModel2": root.childModel!.uuid.UUIDString
                ],
                "clsName": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": root.childModel!.uuid.UUIDString,
                    "properties": ["string": "ok"],
                    "clsName": "TestModel"
                ]
            ]
        ]
        
        XCTAssert(root.childModel != nil, "Child model moved")
        
        client.receivedMessage(Message.unserialize(json)!)
        
        XCTAssert(root.childModel == nil, "Child model moved")
        XCTAssert(root.childModel2 != nil, "Child model moved")
        XCTAssertEqual(scope.modelObjects.count, 2, "Correct number of objects in scope")
    }
    
    func testAddingDependentFirst() {
        let childUUID = NSUUID()
        let childUUID2 = NSUUID()
        
        var json = [
            "type": "ScopeState",
            "index": 2,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": [
                    "string": "set correctly",
                    "childModel2": childUUID.UUIDString
                ],
                "clsName": "TestModel"
            ],
            "fragments": [
                [
                    "type": "add",
                    "uuid": childUUID2.UUIDString,
                    "properties": ["string": "ok2"],
                    "clsName": "TestModel"
                ],
                [
                    "type": "add",
                    "uuid": childUUID.UUIDString,
                    "properties": [
                        "string": "ok1",
                        "childModel": childUUID2.UUIDString
                    ],
                    "clsName": "TestModel"
                ]
            ]
        ]
        
        client.receivedMessage(Message.unserialize(json)!)
        
        XCTAssertEqual(root.childModel2!.uuid, childUUID, "Child model added")
        XCTAssertEqual(root.childModel2!.childModel!.uuid, childUUID2, "Child model added")
        XCTAssertEqual(scope.modelObjects.count, 3, "Correct number of objects in scope")
    }
    
    func testModelValueTypes() {
        let childUUID = NSUUID()
        let childUUID2 = NSUUID()
        
        var json: [String: AnyObject] = [
            "type": "ScopeState",
            "index": 2,
            "scopeIndex": 1,
            "rootFragment": [
                "type": "root",
                "uuid": uuid.UUIDString,
                "properties": [
                    "string": "set correctly",
                    "testType": 1,
                    "color": 0xFF108040,
                    "date" : 100.0,
                    "image": "/9j/4QAYRXhpZgAASUkqAAgAAAAAAAAAAAAAAP/sABFEdWNreQABAAQAAAA8AAD/4QMxaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLwA8P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIenJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJBZG9iZSBYTVAgQ29yZSA1LjYtYzAxNCA3OS4xNTY3OTcsIDIwMTQvMDgvMjAtMDk6NTM6MDIgICAgICAgICI+IDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDQyAyMDE0IChNYWNpbnRvc2gpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjlFNkU5QzAzNTMyMjExRTQ4QzI0RTkzQ0VENjIxMzQ5IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjlFNkU5QzA0NTMyMjExRTQ4QzI0RTkzQ0VENjIxMzQ5Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6OUU2RTlDMDE1MzIyMTFFNDhDMjRFOTNDRUQ2MjEzNDkiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6OUU2RTlDMDI1MzIyMTFFNDhDMjRFOTNDRUQ2MjEzNDkiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz7/7gAOQWRvYmUAZMAAAAAB/9sAhAAGBAQEBQQGBQUGCQYFBgkLCAYGCAsMCgoLCgoMEAwMDAwMDBAMDg8QDw4MExMUFBMTHBsbGxwfHx8fHx8fHx8fAQcHBw0MDRgQEBgaFREVGh8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx//wAARCAAKAAoDAREAAhEBAxEB/8QATAABAQAAAAAAAAAAAAAAAAAAAAcBAQEAAAAAAAAAAAAAAAAAAAAGEAEAAAAAAAAAAAAAAAAAAAAAEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCRplQgAAP/2Q=="
                ],
                "clsName": "TestModel"
            ]
        ]
        client.receivedMessage(Message.unserialize(json)!)
        XCTAssertEqual(root.testType, TestType.Active, "Applied enum")
       
        var comp: [CGFloat] = Array(count: 4, repeatedValue: 0);
        root.color!.getRed(&comp[0], green: &comp[1], blue: &comp[2], alpha: &comp[3])
        var red = Int(comp[0] * 255)
        var green = Int(comp[1] * 255)
        var blue = Int(comp[2] * 255)
        var alpha = Int(comp[3] * 255)
        
        XCTAssertEqual(red, 0xFF, "Applied color")
        XCTAssertEqual(green, 0x10, "Applied color")
        XCTAssertEqual(blue, 0x80, "Applied color")
        XCTAssertEqual(alpha, 0x40, "Applied color")

        XCTAssertEqual(root.date!, NSDate(timeIntervalSince1970: 100.0), "Applied date")
        XCTAssertEqual(root.image!.size.width, CGFloat(10), "Applied image")
        XCTAssertEqual(root.image!.size.height, CGFloat(10), "Applied image")
    }
}
