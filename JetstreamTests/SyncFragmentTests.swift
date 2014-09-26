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
    
    func testCreationFromJSON() {
        
        var model = TestModel()
        
        var json = [
            "type": "add",
            "uuid": model.uuid.UUIDString
        ]

        var fragment = SyncFragment(dictionary: json)
        
        XCTAssertEqual(fragment.objectUUID, model.uuid , "Value change captured")
    }
}
