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
    
    class func unserialize(dictionary: Dictionary<String, AnyObject>) -> Message? {
        let maybeType: AnyObject? = dictionary["type"]
        if let type = maybeType as? String {
            switch type {
            case SessionCreateMessage.messageType:
                return SessionCreateMessage.unserialize(dictionary)
            case SessionCreateResponseMessage.messageType:
                return SessionCreateResponseMessage.unserialize(dictionary)
            default:
                return nil
            }
        }
        return nil
    }
    
}
