//
//  ReplyMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/1/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class ReplyMessage: IndexedMessage {
    
    class var messageType: String {
        return "Reply"
    }
    
    override var type: String {
        return ReplyMessage.messageType
    }
    
    let replyTo: UInt
    let response: [String: AnyObject]
    
    init(index: UInt, replyTo: UInt, response: [String: AnyObject]) {
        self.replyTo = replyTo
        self.response = response
        super.init(index: index)
    }
    
    convenience init(session: Session, replyTo: UInt) {
        self.init(index: session.getIndexForMessage(), replyTo: replyTo, response: [String: AnyObject]())
    }
    
    convenience init(session: Session, replyTo: UInt, response: [String: AnyObject]) {
        self.init(index: session.getIndexForMessage(), replyTo: replyTo, response: response)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["replyTo"] = replyTo
        dictionary["response"] = response
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var maybeIndex: UInt? = dictionary.valueForKey("index")
        var maybeReplyTo: UInt? = dictionary.valueForKey("replyTo")
        var maybeResponse: [String: AnyObject]? = dictionary.valueForKey("response")
        
        if maybeIndex == nil || maybeReplyTo == nil {
            return nil
        } else if maybeResponse == nil {
            return ReplyMessage(index: maybeIndex!, replyTo: maybeReplyTo!, response: [String: AnyObject]())
        } else {
            return ReplyMessage(index: maybeIndex!, replyTo: maybeReplyTo!, response: maybeResponse!)
        }
    }
}
