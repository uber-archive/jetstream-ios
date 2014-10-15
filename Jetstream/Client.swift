//
//  Client.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

let clientVersion = "0.1.0"
let defaultErrorDomain = "com.uber.jetstream"

public enum ClientStatus {
    case Offline
    case Online
}

public class Client {
    /// MARK: Events
    public let onStatusChanged = Signal<(ClientStatus)>()
    public let onSession = Signal<(Session)>()
    public let onSessionDenied = Signal<(Void)>()

    /// MARK: Properties
    let logger = Logging.loggerFor("Client")
    
    public private(set) var status: ClientStatus = .Offline {
        didSet {
            if oldValue != status {
                onStatusChanged.fire(status)
            }
        }
    }
    
    public private(set) var session: Session? {
        didSet {
            if session != nil {
                transport.adapter.sessionEstablished(session!)
                onSession.fire(session!)
            }
        }
    }
    
    let transport: Transport

    /// MARK: Public interface
    public init(options: ConnectionOptions) {
        var defaultAdapter = Transport.defaultTransportAdapter(options)
        transport = Transport(adapter: defaultAdapter)
        bindListeners()
    }
    
    public init(options: WebsocketConnectionOptions) {
        var adapter = WebsocketTransportAdapter(options: options)
        transport = Transport(adapter: adapter)
        bindListeners()
    }
    
    public func connect() {
        transport.connect()
    }
    
    public func close() {
        transport.disconnect()
        session?.close()
        session = nil
    }
    
    /// MARK: Internal interface
    func bindListeners() {
        onStatusChanged.listen(self) { [weak self] (status) in
            if let this = self {
                this.statusChanged(status)
            }
        }
        transport.onStatusChanged.listen(self) { [weak self] (status) in
            if let this = self {
                this.transportStatusChanged(status)
            }
        }
        transport.onMessage.listen(self) { [weak self] (message: Message) in
            asyncMain {
                if let this = self {
                    this.receivedMessage(message)
                }
            }
        }
    }
    
    func statusChanged(clientStatus: ClientStatus) {
        switch clientStatus {
        case .Online:
            logger.info("Online")
            if session == nil {
                transport.sendMessage(SessionCreateMessage())
            }
        case .Offline:
            logger.info("Offline")
        }
    }
    
    func transportStatusChanged(transportStatus: TransportStatus) {
        switch transportStatus {
        case .Closed:
            status = .Offline
        case .Connecting:
            status = .Offline
        case .Connected:
            status = .Online
        }
    }
    
    func receivedMessage(message: Message) {
        switch message {
        case let sessionCreateResponse as SessionCreateResponseMessage:
            if session != nil {
                logger.error("Received session create response with existing session")
            } else if sessionCreateResponse.success == false {
                logger.info("Denied starting session")
                onSessionDenied.fire()
            } else {
                let token = sessionCreateResponse.sessionToken
                logger.info("Starting session with token: \(token)")
                session = Session(client: self, token: token)
            }
        default:
            session?.receivedMessage(message)
        }
    }
}
