//
//  Client.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

let clientVersion = "0.1.0"
let defaultErrorDomain = "com.uber.jetstream"

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
    var scopes = [UInt: Scope]()
    
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
        // TODO: close up any resources
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
            asyncMain {
                self.receivedMessage(message)
            }
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
                session = Session(client: self, token: token)
            }
        case let scopeSyncMessage as ScopeSyncMessage:
            if let scope = scopes[scopeSyncMessage.scopeIndex] {
                if let rootModel = scope.rootModel {
                    if scopeSyncMessage.syncFragments.count > 0 {
                        scope.startApplyingRemote()
                        if scopeSyncMessage.fullState {
                            var syncFragments = scopeSyncMessage.syncFragments
                            let stateMessage = syncFragments.removeAtIndex(0)
                            stateMessage.applyAddToRootModelInScope(scope)
                            scope.applySyncFragments(syncFragments)
                        } else {
                            scope.applySyncFragments(scopeSyncMessage.syncFragments)
                        }
                        scope.endApplyingRemote()
                    } else {
                        logger.error("Received sync message without fragments")
                    }
                }
            }
        case let replyMessage as ReplyMessage:
            // No-op
            break
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
    
    func fetchScope(scope: Scope, callback: (NSError?) -> Void) {
        transport.sendMessage(ScopeFetchMessage(session: session!, name: scope.name)) {
            [unowned self] (response) in
            
            var result: Bool? = response.valueForKey("result")
            var scopeIndex: UInt? = response.valueForKey("scopeIndex")
            
            if result != nil && scopeIndex != nil && result! == true {
                self.scopeAttached(scope, atIndex: scopeIndex!)
                callback(nil)
            } else {
                var definiteErrorCode = 0

                var error: [String: AnyObject]? = response.valueForKey("error")
                var errorMessage: String? = error?.valueForKey("message")
                var errorCode: Int? = error?.valueForKey("code")
                
                if errorCode != nil {
                    definiteErrorCode = errorCode!
                }

                var userInfo = [NSLocalizedDescriptionKey: "Fetch request failed"]
                
                if errorMessage != nil {
                    userInfo[NSLocalizedFailureReasonErrorKey] = errorMessage!
                }
                
                callback(NSError(
                    domain: defaultErrorDomain,
                    code: definiteErrorCode,
                    userInfo: userInfo))
            }
        }
    }
    
    private func scopeAttached(scope: Scope, atIndex: UInt) {
        scopes[atIndex] = scope
        scope.onChanges.listen(self) {
            [unowned self] (syncFragments) in
            self.scopeChanges(scope, atIndex: atIndex, syncFragments: syncFragments)
        }
    }
    
    private func scopeChanges(scope: Scope, atIndex: UInt, syncFragments: [SyncFragment]) {
        if session == nil {
            return
        }
        
        transport.sendMessage(ScopeSyncMessage(
            session: session!,
            scopeIndex: atIndex,
            syncFragments: syncFragments))
    }

}
