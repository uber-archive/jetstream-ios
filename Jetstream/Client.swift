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

/// Connectivity status of the client.
public enum ClientStatus {
    /// Client is offline.
    case Offline
    /// Client is online.
    case Online
}

/// A Client is used to initiate a connection between the application model and the remote Jetstream
/// server. A client uses a TransportAdapter to establish a connection to the server.
@objc public class Client: NSObject {
    // MARK: - Events
    /// Signal that fires whenever the status of the client changes. The fired data contains the
    /// new status for the client.
    public let onStatusChanged = Signal<(ClientStatus)>()
    
    /// Signal that fires whenever the clients gets a new session. THe fired data contains the
    /// new session.
    public let onSession = Signal<(Session)>()
    
    /// Signal that fires whenever a session was denied.
    public let onSessionDenied = Signal<()>()

    // MARK: - Properties

    /// The status of the client.
    public private(set) var status: ClientStatus = .Offline {
        didSet {
            if oldValue != status {
                onStatusChanged.fire(status)
            }
        }
    }
    
    /// The session of the client.
    public private(set) var session: Session? {
        didSet {
            if session != nil {
                transport.adapter.sessionEstablished(session!)
                onSession.fire(session!)
            }
        }
    }
    
    let logger = Logging.loggerFor("Client")
    let transport: Transport
    var sessionCreateParams = [String: AnyObject]()
    
    // MARK: - Public interface
    
    /// Constructs a client.
    ///
    /// :param: transportAdapter The transport adapter to use to connect to the Jetstream server.
    public init(transportAdapter: TransportAdapter) {
        transport = Transport(adapter: transportAdapter)
        super.init()
        bindListeners()
    }
    
    /// Starts connecting the client to the server.
    public func connect() {
        transport.connect()
    }
    
    /// Starts connecting the client to the server with params to supply to server when creating a session.
    public func connectWithSessionCreateParams(sessionCreateParams: [String: AnyObject]) {
        self.sessionCreateParams = sessionCreateParams
        connect()
    }
    
    /// Closes the connection to the server.
    public func close() {
        transport.disconnect()
        session?.close()
        session = nil
    }
    
    /// MARK: - Internal interface
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
                transport.sendMessage(SessionCreateMessage(params: sessionCreateParams))
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
