//
//  ScopeFetchMessage.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/26/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class ScopeFetchMessage: Message {
    class var messageType: String {
        return "ScopeFetch"
    }
    
    override var type: String {
        return ScopeFetchMessage.messageType
    }
    
    let name: String
    let params: [String: AnyObject]
    
    init(index: UInt, name: String, params: [String: AnyObject]) {
        self.name = name
        self.params = params
        super.init(index: index)
    }
    
    convenience init(session: Session, name: String) {
        self.init(index: session.getNextMessageIndex(), name: name, params: [String: AnyObject]())
    }
    
    convenience init(session: Session, name: String, params: [String: AnyObject]) {
        self.init(index: session.getNextMessageIndex(), name: name, params: params)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["name"] = name
        dictionary["params"] = params
        return dictionary
    }
}
