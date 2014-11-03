//
//  ScopeFetchReplyMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/31/14.
//  Copyright (c) 2014 Uber Technologies Inc. All rights reserved.
//

import Foundation

class ScopeFetchReplyMessage: ReplyMessage {
    class var messageType: String {
        return "ScopeFetchResponse"
    }
    
    override var type: String {
        return ScopeFetchReplyMessage.messageType
    }
    
    let scopeIndex: UInt?
    let error: NSError?
    
    init(index: UInt, replyTo: UInt, scopeIndex: UInt?, error: NSError? = nil) {
        self.scopeIndex = scopeIndex
        self.error = error
        super.init(index: index, replyTo: replyTo)
    }
    
    override func serialize() -> [String: AnyObject] {
        assertionFailure("ScopeSyncReplyMessage cannot serialize itself")
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index = dictionary["index"] as? UInt
        var replyTo = dictionary["replyTo"] as? UInt
        var scopeIndex = dictionary["scopeIndex"] as? UInt
        var error: NSError?
        if let serializedError = dictionary["error"] as? [String: AnyObject] {
            error = errorFromDictionary(.SyncFragmentApplyError, serializedError)
        }
        
        if index == nil || replyTo == nil || (scopeIndex == nil && error == nil) {
            return nil
        } else {
            return ScopeFetchReplyMessage(index: index!, replyTo: replyTo!, scopeIndex: scopeIndex, error: error)
        }
    }
}
