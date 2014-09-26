//
//  Message.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class Message {
    
    // Override to provide message type
    var type: String {
        get { return "Message" }
    }
    
    func serialize() -> Dictionary<String, AnyObject> {
        return ["type": type]
    }
    
}
