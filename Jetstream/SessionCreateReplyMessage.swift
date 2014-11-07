//
//  SessionCreateMessageResponse.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/26/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class SessionCreateReplyMessage: NetworkMessage {
    class var messageType: String {
        return "SessionCreateReply"
    }
    
    override var type: String {
        return SessionCreateReplyMessage.messageType
    }

    let success: Bool
    let sessionToken: String
    let response: AnyObject?
    
    init(index: UInt, success: Bool, sessionToken: String, response: AnyObject?) {
        self.success = success
        self.sessionToken = sessionToken
        self.response = response
        super.init(index: index)
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index = dictionary["index"] as? UInt
        var success = dictionary["success"] as? Bool
        var sessionToken = dictionary["sessionToken"] as? String
        var response: AnyObject? = dictionary["response"]
        
        if index == nil || success == nil || sessionToken == nil {
            return nil
        } else {
            return SessionCreateReplyMessage(
                index: index!,
                success: success!,
                sessionToken: sessionToken!,
                response: response)
        }
    }
}
