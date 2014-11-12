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

    let sessionToken: String?
    let error: NSError?
    
    init(index: UInt, sessionToken: String?, error: NSError?) {
        self.sessionToken = sessionToken
        super.init(index: index)
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index = dictionary["index"] as? UInt
        var sessionToken = dictionary["sessionToken"] as? String
        
        
        var error: NSError?
        if let serializedError = dictionary["error"] as? [String: AnyObject] {
            error = errorFromDictionary(.SyncFragmentApplyError, serializedError)
        }
        
        if index == nil || (sessionToken == nil && error == nil) {
            return nil
        } else {
            return SessionCreateReplyMessage(
                index: index!,
                sessionToken: sessionToken,
                error: error)
        }
    }
}
