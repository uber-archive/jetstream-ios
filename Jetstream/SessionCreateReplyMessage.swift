//
//  SessionCreateReplyMessage.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
    
    class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
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
