//
//  ReplyMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/1/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class ReplyMessage: Message {
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
        self.init(index: session.getNextMessageIndex(), replyTo: replyTo, response: [String: AnyObject]())
    }
    
    convenience init(session: Session, replyTo: UInt, response: [String: AnyObject]) {
        self.init(index: session.getNextMessageIndex(), replyTo: replyTo, response: response)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["replyTo"] = replyTo
        dictionary["response"] = response
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index = dictionary["index"] as? UInt
        var replyTo = dictionary["replyTo"] as? UInt
        var response = dictionary["response"] as? [String: AnyObject]
        
        if index == nil || replyTo == nil {
            return nil
        } else if response == nil {
            return ReplyMessage(index: index!, replyTo: replyTo!, response: [String: AnyObject]())
        } else {
            return ReplyMessage(index: index!, replyTo: replyTo!, response: response!)
        }
    }
}
