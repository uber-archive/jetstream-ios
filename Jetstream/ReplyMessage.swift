//
//  ReplyMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/1/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class ReplyMessage: Message {
    
    let replyTo: UInt
    
    init(index: UInt, replyTo: UInt) {
        self.replyTo = replyTo
        super.init(index: index)
    }
    
    convenience init(session: Session, replyTo: UInt) {
        self.init(index: session.getNextMessageIndex(), replyTo: replyTo)
    }

    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["replyTo"] = replyTo
        return dictionary
    }
}
