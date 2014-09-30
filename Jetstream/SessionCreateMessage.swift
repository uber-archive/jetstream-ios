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
        get { return "SessionCreate" }
    }
    
    override var type: String {
        get { return SessionCreateMessage.messageType }
    }
    
    let params: [String: String]
    let version: String

    convenience override init() {
        self.init(params: [String: String]())
    }
    
    convenience init(params: [String: String]) {
        self.init(params: params, version: clientVersion)
    }
    
    init(params: [String: String], version: String) {
        self.params = params
        self.version = version
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
