//
//  SessionCreateMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

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
