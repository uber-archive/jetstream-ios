//
//  Transport.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

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
    func disconnect()
    func reconnect()
    func sendMessage(message: Message)
    func sessionEstablished(session: Session)
}

class Transport {
    typealias ReplyCallback = ([String: AnyObject]) -> Void
    
    class func defaultTransportAdapter(options: ConnectionOptions) -> TransportAdapter {
        return WebsocketTransportAdapter(options: options)
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
    var waitingReply = [UInt: ReplyCallback]()
    
    init(adapter: TransportAdapter) {
        self.adapter = adapter
        onStatusChanged = adapter.onStatusChanged
        onMessage = adapter.onMessage
        bindListeners()
    }
    
    func bindListeners() {
        onStatusChanged.listen(self) { [weak self] (status) in
            if let this = self {
                this.statusChanged(status)
            }
        }
        onMessage.listen(self) { [weak self] (message) in
            if let this = self {
                this.messageReceived(message)
            }
        }
    }
    
    func statusChanged(status: TransportStatus) {
        switch status {
        case .Closed:
            logger.info("Closed")
        case .Connecting:
            logger.info("Connecting using \(self.adapter.adapterName) to \(self.adapter.options.url)")
        case .Connected:
            logger.info("Connected")
        }
    }
    
    func messageReceived(message: Message) {
        switch message {
        case let replyMessage as ReplyMessage:
            if let callback = waitingReply[replyMessage.replyTo] {
                callback(replyMessage.response)
                waitingReply.removeValueForKey(replyMessage.replyTo)
            }
        default:
            break
        }
    }
    
    func connect() {
        adapter.connect()
    }
    
    func disconnect() {
        adapter.disconnect()
    }
    
    func reconnect() {
        adapter.reconnect()
    }
    
    func sendMessage(message: Message) {
        adapter.sendMessage(message)
    }
    
    func sendMessage(message: Message, withCallback: ReplyCallback) {
        adapter.sendMessage(message)
        waitingReply[message.index] = withCallback
    }
}
