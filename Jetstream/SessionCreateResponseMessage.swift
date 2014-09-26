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
        get { return "SessionCreateResponse" }
    }
    
    override var type: String {
        get { return SessionCreateResponseMessage.messageType }
    }

    let success: Bool
    let sessionToken: String
    let response: AnyObject?
    
    init(success: Bool, sessionToken: String, response: AnyObject?) {
        self.success = success
        self.sessionToken = sessionToken
        self.response = response
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var maybeSuccess: Bool?
        var maybeSessionToken: String?
        var maybeResponse: AnyObject? = dictionary["response"]
        
        switch dictionary["success"] {
        case let success as Bool:
            maybeSuccess = success
        default:
            maybeSuccess = nil
        }
        
        switch dictionary["sessionToken"] {
        case let sessionToken as String:
            maybeSessionToken = sessionToken
        default:
            maybeSessionToken = nil
        }
        
        if maybeSuccess == nil || maybeSessionToken == nil {
            return nil
        } else {
            return SessionCreateResponseMessage(
                success: maybeSuccess!,
                sessionToken: maybeSessionToken!,
                response: maybeResponse)
        }
    }
    
}
