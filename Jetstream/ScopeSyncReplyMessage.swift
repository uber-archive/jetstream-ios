//
//  ScopeSyncReplyMessage.swift
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
    
    let fragmentReplies: [SyncFragmentReply]
    
    init(index: UInt, replyTo: UInt, fragmentReplies: [SyncFragmentReply]) {
        self.fragmentReplies = fragmentReplies
        super.init(index: index, replyTo: replyTo)
    }
    
    override func serialize() -> [String: AnyObject] {
        assertionFailure("ScopeSyncReplyMessage cannot serialize itself")
        return [String: AnyObject]()
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        let index = dictionary["index"] as? UInt
        let replyTo = dictionary["replyTo"] as? UInt
        let serializedFragmentReplies = dictionary["fragmentReplies"] as? [[String: AnyObject]]
        
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
                    error = errorFromDictionary(.SyncFragmentApplyError, error: serializedError)
                }
                
                if let serializedModifications = serializedFragmentReply["modifications"] as? [String: AnyObject] {
                    modifications = serializedModifications
                }
                
                let fragmentReply = SyncFragmentReply(accepted: accepted, error: error, modifications: modifications)
                fragmentReplies.append(fragmentReply)
            }
            
            return ScopeSyncReplyMessage(index: index!, replyTo: replyTo!, fragmentReplies: fragmentReplies)
        }
    }
}
