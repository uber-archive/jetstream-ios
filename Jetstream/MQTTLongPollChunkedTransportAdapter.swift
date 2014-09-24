//
//  MQTTLongPollChunkedTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class MQTTLongPollChunkedTransportAdapter: TransportAdapter {
    
    let onStatusChanged = Signal<(TransportStatus)>()
    let onMessage = Signal<(Message)>()
    
    private var _status: TransportStatus = .Closed
    var status: TransportStatus {
        get {
            return _status
        }
        set {
            onStatusChanged.fire(newValue)
            _status = newValue
        }
    }
    
    private let options: ConnectionOptions
    
    init(options: ConnectionOptions) {
        self.options = options
    }
    
    func connect() {
        _status = .Connecting
    }
    
    func sendMessage(message: Message) {
        
    }
    
}
