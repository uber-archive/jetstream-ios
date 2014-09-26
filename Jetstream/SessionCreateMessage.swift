//
//  SessionCreateMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class SessionCreateMessage: Message {
    
    override var type: String {
        get { return "SessionCreate" }
    }
    
    override func serialize() -> Dictionary<String, AnyObject> {
        var dictionary = super.serialize()
        dictionary["params"] = [String:String]()
        return dictionary
    }
    
}
