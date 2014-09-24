//
//  Transport.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

enum TransportStatus {
    case Closed
    case Connecting
    case Connected
}

protocol TransportAdapter {
    
    var onStatusChanged: Signal<(TransportStatus)> { get }
    var onMessage: Signal<(Message)> { get }
    
    var status: TransportStatus { get }
    
    func connect()
    func sendMessage(message: Message)
    
}

class Transport {
    
    class func defaultTransportAdapter(options: ConnectionOptions) -> TransportAdapter {
        return PollTransportAdapter(options: options)
    }
    
    let logger = Logging.loggerFor("Transport")
    
    let onStatusChanged: Signal<(TransportStatus)>
    let onMessage: Signal<Message>
    
    var status: TransportStatus {
        get {
            return adapter.status
        }
    }
    
    let adapter: TransportAdapter
    
    init(adapter: TransportAdapter) {
        self.adapter = adapter
        self.onStatusChanged = adapter.onStatusChanged
        self.onMessage = adapter.onMessage
    }
    
    func connect() {
        logger.info("Connecting")
        adapter.connect()
    }
    
    func sendMessage(message: Message) {
        adapter.sendMessage(message)
    }
    
}
