//
//  ConnectionOptions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public class ConnectionOptions {
    
    public private(set) var url: String
    
    public init(url: String) {
        self.url = url
    }
    
}
