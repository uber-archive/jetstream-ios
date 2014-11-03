//
//  ScopeSyncReplyMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/31/14.
//  Copyright (c) 2014 Uber Technologies Inc. All rights reserved.
//

import Foundation


struct FragmentSyncReply {
    var accepted: Bool = true
    var error: NSError?
    var augment: [NSString: AnyObject]?
}

class ScopeSyncReplyMessage: ReplyMessage {
    class var messageType: String {
        return "ScopeSyncReply"
    }
    
    override var type: String {
        return ScopeSyncReplyMessage.messageType
    }
    
    let fragmentReplies = [FragmentSyncReply]()
    
    init(index: UInt, replyTo: UInt, fragmentReplies: [FragmentSyncReply]) {
        self.fragmentReplies = fragmentReplies
        super.init(index: index, replyTo: replyTo)
    }
    
    override func serialize() -> [String: AnyObject] {
        assertionFailure("ScopeSyncReplyMessage cannot serialize itself")
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index = dictionary["index"] as? UInt
        var replyTo = dictionary["replyTo"] as? UInt
        var serializedFragmentResponses = dictionary["fragmentResponses"] as? [[String: AnyObject]]
        
        if index == nil || replyTo == nil || serializedFragmentResponses == nil {
            return nil
        } else {
            var fragmentReplies = [FragmentSyncReply]()
            for serializedFragmentResponse in serializedFragmentResponses! {
                var accepted = true
                var error: NSError?
                var augment = [NSString: AnyObject]()
                
                if let serializedError = serializedFragmentResponse["error"] as? [String: AnyObject] {
                    accepted = false
                    error = errorFromDictionary(.SyncFragmentApplyError, serializedError)
                }
                
                if let serializedAugment = serializedFragmentResponse["augment"] as? [String: AnyObject] {
                    augment = serializedAugment
                }
                
                var fragmentReply = FragmentSyncReply(accepted: accepted, error: error, augment: augment)
                fragmentReplies.append(fragmentReply)
            }
            
            return ScopeSyncReplyMessage(index: index!, replyTo: replyTo!, fragmentReplies: fragmentReplies)
        }
    }
}
