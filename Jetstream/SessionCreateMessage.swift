//
//  SessionCreateMessage.swift
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

class SessionCreateMessage: NetworkMessage {
    class var messageType: String {
        return "SessionCreate"
    }
    
    override var type: String {
        return SessionCreateMessage.messageType
    }
    
    let params: [String: AnyObject]
    let version: String
    
    init(params: [String: AnyObject], version: String) {
        self.params = params
        self.version = version
        super.init(index: 0)
    }
    
    convenience init() {
        self.init(params: [String: AnyObject]())
    }
    
    convenience init(params: [String: AnyObject]) {
        self.init(params: params, version: clientVersion)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["params"] = params
        dictionary["version"] = version
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var params = dictionary["params"] as? [String: AnyObject]
        var version = dictionary["version"] as? String
        
        if params != nil && version != nil {
            return SessionCreateMessage(params: params!, version: version!)
        } else if params != nil {
            return SessionCreateMessage(params: params!)
        } else {
            return SessionCreateMessage()
        }
    }
}
