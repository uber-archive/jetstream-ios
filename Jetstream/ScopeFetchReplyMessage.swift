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
        return "ScopeFetchReply"
    }
    
    override var type: String {
        return ScopeFetchReplyMessage.messageType
    }
    
    let success: Bool
    let scopeIndex: UInt?
    let error: NSError?
    
    init(index: UInt, replyTo: UInt, success: Bool, scopeIndex: UInt?, error: NSError?) {
        self.success = success
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
        var success = dictionary["success"] as? Bool
        var scopeIndex = dictionary["scopeIndex"] as? UInt
        
        var error: NSError?
        if let serializedError = dictionary["error"] as? [String: AnyObject] {
            error = errorFromDictionary(.SyncFragmentApplyError, serializedError)
        }
        
        if index == nil || replyTo == nil || success == nil || (scopeIndex == nil && error == nil) {
            return nil
        } else {
            return ScopeFetchReplyMessage(
                index: index!,
                replyTo: replyTo!,
                success: success!,
                scopeIndex: scopeIndex,
                error: error)
        }
    }
}
