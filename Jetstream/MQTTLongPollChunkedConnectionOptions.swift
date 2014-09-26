//
//  MQTTLongPollChunkedConnectionOptions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public class MQTTLongPollChunkedConnectionOptions: ConnectionOptions {
    
    public let receiveURL: String
    public let sendURL: String
    public let headers: [String:String]
    public let sendIdRequired: Bool
    
    convenience public init(receiveURL: String, sendURL: String) {
        self.init(receiveURL: receiveURL, sendURL: sendURL, headers: [String:String](), sendIdRequired: false)
    }
    
    convenience public init(receiveURL: String, sendURL: String, headers: [String:String]) {
        self.init(receiveURL: receiveURL, sendURL: sendURL, headers: headers, sendIdRequired: false)
    }
    
    public init(receiveURL: String, sendURL: String, headers: [String:String], sendIdRequired: Bool) {
        self.receiveURL = receiveURL
        self.sendURL = sendURL
        self.headers = headers
        self.sendIdRequired = sendIdRequired
        super.init(url: receiveURL)
    }
    
}
