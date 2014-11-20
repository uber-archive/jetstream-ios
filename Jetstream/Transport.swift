//
//  Transport.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import Signals

/// Transport adapters initialize themselves with options that conform to ConnectionOptions.
public protocol ConnectionOptions {
    /// The url to connect to.
    var url: NSURL { get }
}

public enum TransportStatus {
    case Closed
    case Connecting
    case Connected
}

public protocol TransportAdapter {
    var onStatusChanged: Signal<(TransportStatus)> { get }
    var onMessage: Signal<(NetworkMessage)> { get }
    
    var adapterName: String { get }
    var status: TransportStatus { get }
    var options: ConnectionOptions { get }
    
    func connect()
    func disconnect()
    func reconnect()
    func sendMessage(message: NetworkMessage)
    func sessionEstablished(session: Session)
}

typealias ReplyCallback = (ReplyMessage) -> Void

class Transport {
    class func defaultTransportAdapter(options: ConnectionOptions) -> TransportAdapter {
        return WebSocketTransportAdapter(options: WebSocketConnectionOptions(url: options.url))
    }
    
    let logger = Logging.loggerFor("Transport")
    let onStatusChanged: Signal<(TransportStatus)>
    let onMessage: Signal<NetworkMessage>
    let adapter: TransportAdapter
    var waitingReply = [UInt: ReplyCallback]()
    
    var status: TransportStatus {
        return adapter.status
    }

    init(adapter: TransportAdapter) {
        self.adapter = adapter
        onStatusChanged = adapter.onStatusChanged
        onMessage = adapter.onMessage
        bindListeners()
    }
    
    func bindListeners() {
        onStatusChanged.listen(self) { [weak self] (status) in
            if let definiteSelf = self {
                definiteSelf.statusChanged(status)
            }
        }
        onMessage.listen(self) { [weak self] (message) in
            if let definiteSelf = self {
                definiteSelf.messageReceived(message)
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
    
    func messageReceived(message: NetworkMessage) {
        switch message {
        case let replyMessage as ReplyMessage:
            if let callback = waitingReply[replyMessage.replyTo] {
                callback(replyMessage)
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
    
    func sendMessage(message: NetworkMessage) {
        adapter.sendMessage(message)
    }
    
    func sendMessage(message: NetworkMessage, withCallback: ReplyCallback) {
        adapter.sendMessage(message)
        waitingReply[message.index] = withCallback
    }
}
