//
//  MQTTLongPollChunkedTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class MQTTLongPollChunkedTransportAdapter: TransportAdapter {
    
    private struct Static {
        static var onceToken : dispatch_once_t = 0
    }
    
    let logger = Logging.loggerFor("MQTTLongPollChunkedTransportAdapter")
    
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
        setupOnce()
    }
    
    func connect() {
        _status = .Connecting
    }
    
    func sendMessage(message: Message) {
        
    }
    
    /// MARK: Private interface
    
    private func setupOnce() {
        dispatch_once(&Static.onceToken) {
//            mosquitto_lib_init()
        }
    }
    
}
