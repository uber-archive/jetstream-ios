//
// PingMessage.swift
// Jetstream
// 
// Copyright (c) 2014 Uber Technologies, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

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
