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
    
    func serialize() -> [String: AnyObject] {
        return ["type": type]
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        let maybeType: AnyObject? = dictionary["type"]
        if let type = maybeType as? String {
            switch type {
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

class IndexedMessage: Message {
    
    let index: UInt
    
    convenience init(session: Session) {
        self.init(index: session.getIndexForMessage())
    }
    
    init(index: UInt) {
        self.index = index
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["index"] = index
        return dictionary
    }
}
