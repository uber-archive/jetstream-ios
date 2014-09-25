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
    
    var adapterName: String { get }
    var status: TransportStatus { get }
    var options: ConnectionOptions { get }
    
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
        onStatusChanged.listen(self) { [unowned self] (status) in
            switch (status) {
            case .Closed:
                self.logger.info("Closed")
            case .Connecting:
                self.logger.info("Connecting using \(adapter.adapterName) to \(adapter.options.url)")
            case .Connected:
                self.logger.info("Connected")
            }
        }
    }
    
    func connect() {
        adapter.connect()
    }
    
    func sendMessage(message: Message) {
        adapter.sendMessage(message)
    }
    
}
