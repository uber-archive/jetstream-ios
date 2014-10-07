//
//  SessionCreateMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class SessionCreateMessage: Message {
    
    class var messageType: String {
        return "SessionCreate"
    }
    
    override var type: String {
        return SessionCreateMessage.messageType
    }
    
    let params: [String: String]
    let version: String
    
    init(params: [String: String], version: String) {
        self.params = params
        self.version = version
    }
    
    convenience override init() {
        self.init(params: [String: String]())
    }
    
    convenience init(params: [String: String]) {
        self.init(params: params, version: clientVersion)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["params"] = params
        dictionary["version"] = version
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var maybeParams: [String: String]? = dictionary.valueForKey("params")
        var maybeVersion: String? = dictionary.valueForKey("version")
        
        if maybeParams != nil && maybeVersion != nil {
            return SessionCreateMessage(params: maybeParams!, version: maybeVersion!)
        } else if maybeParams != nil {
            return SessionCreateMessage(params: maybeParams!)
        } else {
            return SessionCreateMessage()
        }
    }
}
