//
//  Client.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

let clientVersion = "0.1.0"

public enum ClientStatus {
    case Offline
    case Online
}

public class Client {
    
    let logger = Logging.loggerFor("Client")
    
    /// MARK: Events
    
    public let onStatusChanged = Signal<(ClientStatus)>()
    public let onSession = Signal<(Session)>()
    public let onSessionDenied = Signal<(Void)>()

    /// MARK: Properties
    
    public private(set) var status: ClientStatus = .Offline {
        didSet {
            onStatusChanged.fire(status)
        }
    }
    
    public private(set) var session: Session? {
        didSet {
            if session != nil {
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
    
    public init(options: MQTTLongPollChunkedConnectionOptions) {
        var adapter = MQTTLongPollChunkedTransportAdapter(options: options)
        transport = Transport(adapter: adapter)
        bindListeners()
    }
    
    public func connect() {
        transport.connect()
    }
    
    public func close() {
        // Close up any resources
    }
    
    /// MARK: Private interface
    
    private func bindListeners() {
        onStatusChanged.listen(self) { [unowned self] (status) in
            switch status {
            case .Online:
                self.logger.info("Online")
                if self.session == nil {
                    self.createSession()
                } else {
                    self.resumeSession()
                }
            case .Offline:
                self.logger.info("Offline")
            }
        }
        transport.onStatusChanged.listen(self) { [unowned self] (status: TransportStatus) in
            switch status {
            case .Closed:
                self.status = .Offline
            case .Connecting:
                self.status = .Offline
            case .Connected:
                self.status = .Online
            }
        }
        transport.onMessage.listen(self) { [unowned self] (message: Message) in
            self.receivedMessage(message)
        }
    }
    
    private func receivedMessage(message: Message) {
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
                session = Session(token: token)
            }
        default:
            logger.debug("Unrecognized message received")
        }
    }
    
    private func createSession() {
        transport.sendMessage(SessionCreateMessage())
    }
    
    private func resumeSession() {
        // TODO: implement
    }

}
