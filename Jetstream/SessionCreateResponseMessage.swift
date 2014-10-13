//
//  SessionCreateMessageResponse.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/26/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class SessionCreateResponseMessage: Message {
    class var messageType: String {
        return "SessionCreateResponse"
    }
    
    override var type: String {
        return SessionCreateResponseMessage.messageType
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
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index: UInt? = dictionary.valueForKey("index")
        var success: Bool? = dictionary.valueForKey("success")
        var sessionToken: String? = dictionary.valueForKey("sessionToken")
        var response: AnyObject? = dictionary["response"]
        
        if index == nil || success == nil || sessionToken == nil {
            return nil
        } else {
            return SessionCreateResponseMessage(
                index: index!,
                success: success!,
                sessionToken: sessionToken!,
                response: response)
        }
    }
}
