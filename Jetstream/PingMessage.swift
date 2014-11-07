//
//  PingMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/13/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public class PingMessage: NetworkMessage {
    class var messageType: String {
        return "Ping"
    }
    
    override var type: String {
        return PingMessage.messageType
    }
    
    public let ack: UInt
    public let resendMissing: Bool
    
    init(index: UInt, ack: UInt, resendMissing: Bool) {
        self.ack = ack
        self.resendMissing = resendMissing
        super.init(index: index)
    }
    
    public convenience init(session: Session) {
        self.init(index: 0, ack: session.serverIndex, resendMissing: false)
    }
    
    public convenience init(session: Session, resendMissing: Bool) {
        self.init(index: 0, ack: session.serverIndex, resendMissing: resendMissing)
    }
    
    public override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["ack"] = ack
        dictionary["resendMissing"] = resendMissing
        return dictionary
    }

    public override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index = dictionary["index"] as? UInt
        var ack = dictionary["ack"] as? UInt
        var resendMissing = dictionary["resendMissing"] as? Bool
        
        if index == nil || ack == nil || resendMissing == nil {
            return nil
        } else {
            return PingMessage(index: index!, ack: ack!, resendMissing: resendMissing!)
        }
    }
}
