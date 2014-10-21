//
//  ConnectionOptions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public class ConnectionOptions {
    public let url: NSURL
    
    public init(url: NSURL) {
        self.url = url
    }
}
