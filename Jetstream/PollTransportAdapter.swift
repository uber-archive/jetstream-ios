//
//  MQTTLongPollChunkedTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

class PollTransportAdapter: TransportAdapter {
    
    private struct Static {
        static let className = "PollTransportAdapter"
    }
    
    let logger = Logging.loggerFor(Static.className)
    
    let onStatusChanged = Signal<(TransportStatus)>()
    let onMessage = Signal<(Message)>()

    let adapterName = Static.className
    
    var status: TransportStatus = .Closed {
        didSet {
            onStatusChanged.fire(status)
        }
    }

    let options: ConnectionOptions
    
    init(options: ConnectionOptions) {
        self.options = options
    }
    
    func connect() {
        status = .Connecting
    }
    
    func sendMessage(message: Message) {
        
    }
    
    /// MARK: Private interface
    
}
