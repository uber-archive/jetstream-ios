//
//  ConnectionOptions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public class ConnectionOptions {
    
    let _url: String
    public var url: String {
        get {
            return _url
        }
    }
    
    public init(url: String) {
        _url = url
    }
    
}
