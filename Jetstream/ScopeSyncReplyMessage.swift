//
//  ScopeSyncReplyMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/31/14.
//  Copyright (c) 2014 Uber Technologies Inc. All rights reserved.
//

import Foundation


struct SyncFragmentReply {
    var accepted: Bool = true
    var error: NSError?
    var modifications: [NSString: AnyObject]?
}

class ScopeSyncReplyMessage: ReplyMessage {
    class var messageType: String {
        return "ScopeSyncReply"
    }
    
    override var type: String {
        return ScopeSyncReplyMessage.messageType
    }
    
    let fragmentReplies = [SyncFragmentReply]()
    
    init(index: UInt, replyTo: UInt, fragmentReplies: [SyncFragmentReply]) {
        self.fragmentReplies = fragmentReplies
        super.init(index: index, replyTo: replyTo)
    }
    
    override func serialize() -> [String: AnyObject] {
        assertionFailure("ScopeSyncReplyMessage cannot serialize itself")
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index = dictionary["index"] as? UInt
        var replyTo = dictionary["replyTo"] as? UInt
        var serializedFragmentReplies = dictionary["fragmentReplies"] as? [[String: AnyObject]]
        
        if index == nil || replyTo == nil || serializedFragmentReplies == nil {
            return nil
        } else {
            var fragmentReplies = [SyncFragmentReply]()
            for serializedFragmentReply in serializedFragmentReplies! {
                var accepted = true
                var error: NSError?
                var modifications = [NSString: AnyObject]()
                
                if let serializedError = serializedFragmentReply["error"] as? [String: AnyObject] {
                    accepted = false
                    error = errorFromDictionary(.SyncFragmentApplyError, serializedError)
                }
                
                if let serializedModifications = serializedFragmentReply["modifications"] as? [String: AnyObject] {
                    modifications = serializedModifications
                }
                
                var fragmentReply = SyncFragmentReply(accepted: accepted, error: error, modifications: modifications)
                fragmentReplies.append(fragmentReply)
            }
            
            return ScopeSyncReplyMessage(index: index!, replyTo: replyTo!, fragmentReplies: fragmentReplies)
        }
    }
}
