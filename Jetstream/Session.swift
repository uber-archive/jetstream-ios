//
//  Session.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public class Session {
    
    let client: Client
    public var token: String
    
    var nextIndex: UInt = 1
    
    init(client: Client, token: String) {
        self.client = client
        self.token = token
    }
    
    /// MARK: Public interface
    
    public func fetch(scope: Scope, callback: (NSError?) -> Void) {
        client.fetchScope(scope, callback: callback)
    }
    
    /// MARK: Internal interface
    
    func getIndexForMessage() -> UInt {
        let index = nextIndex
        nextIndex += 1
        return index
    }
    
}
