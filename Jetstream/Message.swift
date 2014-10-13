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
        return "Message"
    }
    
    let index: UInt
    
    init(index: UInt) {
        self.index = index
    }
    
    convenience init(session: Session) {
        self.init(index: session.getIndexForMessage())
    }
    
    func serialize() -> [String: AnyObject] {
        return ["type": type, "index": index]
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        let type: AnyObject? = dictionary["type"]
        if let definiteType = type as? String {
            switch definiteType {
            case SessionCreateMessage.messageType:
                return SessionCreateMessage.unserialize(dictionary)
            case SessionCreateResponseMessage.messageType:
                return SessionCreateResponseMessage.unserialize(dictionary)
            case ReplyMessage.messageType:
                return ReplyMessage.unserialize(dictionary)
            case ScopeStateMessage.messageType:
                return ScopeStateMessage.unserialize(dictionary)
            case ScopeSyncMessage.messageType:
                return ScopeSyncMessage.unserialize(dictionary)
            default:
                return nil
            }
        }
        return nil
    }
}
