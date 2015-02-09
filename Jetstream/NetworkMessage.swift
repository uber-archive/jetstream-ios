//
//  NetworkMessage.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
    
    public class func unserializeDictionary(dictionary: [String: AnyObject]) -> NetworkMessage? {
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
