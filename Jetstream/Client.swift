//
//  Client.swift
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

let clientVersion = "0.2.0"
let defaultErrorDomain = "com.uber.jetstream"

/// Connectivity status of the client.
public enum ClientStatus {
    /// Client is offline.
    case Offline
    /// Client is online.
    case Online
}

/// A function that when invoked creates a TransportAdapter for use.
public typealias TransportAdapterFactory = () -> TransportAdapter

/// A Client is used to initiate a connection between the application model and the remote Jetstream
/// server. A client uses a TransportAdapter to establish a connection to the server.
@objc public class Client: NSObject {
    // MARK: - Events
    /// Signal that fires whenever the status of the client changes. The fired data contains the
    /// new status for the client.
    public let onStatusChanged = Signal<(ClientStatus)>()
    
    /// Signal that fires whenever the clients gets a new session. The fired data contains the
    /// new session.
    public let onSession = Signal<(Session)>()
    
    /// Signal that fires whenever a session was denied.
    public let onSessionDenied = Signal<()>()
    
    /// Signal that fires whenever a message is sent that is waiting an acknowledgment from the 
    /// server.  This can be observed to tell when server has a lot of messages it has not replied to.
    public let onWaitingRepliesCountChanged: Signal<(UInt)>

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
    let transportAdapterFactory: TransportAdapterFactory
    let restartSessionOnFatalError: Bool
    var transport: Transport
    var sessionCreateParams = [String: AnyObject]()
    
    // MARK: - Public interface
    
    /// Constructs a client.
    ///
    /// - parameter transportAdapterFactory: The factory used to create a transport adapter to connect to a Jetstream server.
    /// - parameter restartSessionOnFatalError: Whether to restart a session on a fatal session or transport error.
    public init(transportAdapterFactory: TransportAdapterFactory, restartSessionOnFatalError: Bool = true) {
        self.transportAdapterFactory = transportAdapterFactory
        self.transport = Transport(adapter: transportAdapterFactory())
        self.onWaitingRepliesCountChanged = transport.onWaitingRepliesCountChanged
        self.restartSessionOnFatalError = restartSessionOnFatalError
        super.init()
        bindListeners()
    }
    
    /// Starts connecting the client to the server.
    public func connect() {
        transport.connect()
    }
    
    /// Starts connecting the client to the server with params to supply to server when creating a session.
    ///
    /// - parameter sessionCreateParams: The params that should be sent along with the session create request.
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
        bindTransportListeners()
    }
    
    func bindTransportListeners() {
        transport.onStatusChanged.listen(self) { [weak self] (status) in
            if let this = self {
                this.transportStatusChanged(status)
            }
        }
        transport.onMessage.listen(self) { [weak self] (message: NetworkMessage) in
            asyncMain {
                if let this = self {
                    this.receivedMessage(message)
                }
            }
        }
    }
    
    func unbindTransportListeners() {
        transport.onStatusChanged.removeListener(self)
        transport.onMessage.removeListener(self)
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
        case .Fatal:
            status = .Offline
            if restartSessionOnFatalError && session != nil {
                reinitializeTransportAndRestartSession()
            }
        }
    }
    
    func receivedMessage(message: NetworkMessage) {
        switch message {
        case let sessionCreateReply as SessionCreateReplyMessage:
            if session != nil {
                logger.error("Received session create response with existing session")
            } else if let token = sessionCreateReply.sessionToken  {
                logger.info("Starting session with token: \(token)")
                session = Session(client: self, token: token)
            } else {
                logger.info("Denied starting session, error: \(sessionCreateReply.error)")
                onSessionDenied.fire()
            }
        default:
            session?.receivedMessage(message)
        }
    }
    
    func reinitializeTransportAndRestartSession() {
        var scopesAndFetchParams = [ScopesWithFetchParams]()
        if let scopesByIndex = session?.scopes {
            scopesAndFetchParams = Array(scopesByIndex.values)
        }
        
        session?.close()
        session = nil
        
        onSession.listenOnce(self) { [weak self] session in
            if let this = self {
                for (scope, params) in scopesAndFetchParams {
                    session.fetch(scope, params: params) { error in
                        if let _ = error {
                            this.logger.error("Received error refetching scope '\(scope.name)': \(error)")
                        }
                    }
                }
            }
        }

        unbindTransportListeners()

        transport = Transport(adapter: transportAdapterFactory())
        bindTransportListeners()

        connect()
    }
}
