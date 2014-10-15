//
//  PingMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/13/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class PingMessage: Message {
    class var messageType: String {
        return "Ping"
    }
    
    override var type: String {
        return PingMessage.messageType
    }
    
    let ack: UInt
    let resendMissing: Bool
    
    init(index: UInt, ack: UInt, resendMissing: Bool) {
        self.ack = ack
        self.resendMissing = resendMissing
        super.init(index: index)
    }
    
    convenience init(session: Session) {
        self.init(index: 0, ack: session.serverIndex, resendMissing: false)
    }
    
    convenience init(session: Session, resendMissing: Bool) {
        self.init(index: 0, ack: session.serverIndex, resendMissing: resendMissing)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["ack"] = ack
        dictionary["resendMissing"] = resendMissing
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index: UInt? = dictionary.valueForKey("index")
        var ack: UInt? = dictionary.valueForKey("ack")
        var resendMissing: Bool? = dictionary.valueForKey("resendMissing")
        
        if index == nil || ack == nil || resendMissing == nil {
            return nil
        } else {
            return PingMessage(index: index!, ack: ack!, resendMissing: resendMissing!)
        }
    }
}
