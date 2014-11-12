//
//  Message.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

/// A message wrapper used by Jetstream to communicate between the client and server. The message does not have
/// a public interface as netwotk messages are internal to Jetstream.
public class NetworkMessage {
    // Override to provide message type
    var type: String {
        return "Message"
    }
    
    public let index: UInt
    
    init(index: UInt) {
        self.index = index
    }
    
    convenience init(session: Session) {
        self.init(index: session.getNextMessageIndex())
    }
    
    public func serialize() -> [String: AnyObject] {
        return ["type": type, "index": index]
    }
    
    public class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        let type: AnyObject? = dictionary["type"]
        if let definiteType = type as? String {
            switch definiteType {
            case SessionCreateMessage.messageType:
                return SessionCreateMessage.unserialize(dictionary)
            case SessionCreateReplyMessage.messageType:
                return SessionCreateReplyMessage.unserialize(dictionary)
            case SessionCreateReplyMessage.messageType:
                return SessionCreateReplyMessage.unserialize(dictionary)
            case ScopeFetchReplyMessage.messageType:
                return ScopeFetchReplyMessage.unserialize(dictionary)
            case ScopeStateMessage.messageType:
                return ScopeStateMessage.unserialize(dictionary)
            case ScopeSyncMessage.messageType:
                return ScopeSyncMessage.unserialize(dictionary)
            case ScopeSyncReplyMessage.messageType:
                return ScopeSyncReplyMessage.unserialize(dictionary)
            case PingMessage.messageType:
                return PingMessage.unserialize(dictionary)
            default:
                return nil
            }
        }
        return nil
    }
}
