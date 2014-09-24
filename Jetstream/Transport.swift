//
//  Transport.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

enum TransportStatus {
    case Closed
    case Connecting
    case Connected
}

class Transport {
    
    class func defaultTransportAdapter(options: ConnectionOptions) -> TransportAdapter {
        return MQTTLongPollChunkedTransportAdapter(options: options)
    }
    
    let logger = Logging.loggerFor("Transport")
    
    let onStatusChanged: Signal<(TransportStatus)>
    
    var status: TransportStatus {
        get {
            return adapter.status
        }
    }
    
    private let adapter: TransportAdapter
    
    init(adapter: TransportAdapter) {
        self.adapter = adapter
        self.onStatusChanged = adapter.onStatusChanged
    }
    
    func connect() {
        logger.info("Connecting")
        adapter.connect()
    }
    
    func sendMessage(message: Message) {
        adapter.sendMessage(message)
    }
    
}
