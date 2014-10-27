//
//  Session.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public class Session {
    /// The token of the session
    public let token: String
    
    let logger = Logging.loggerFor("Client")
    let client: Client
    var nextMessageIndex: UInt = 1
    var serverIndex: UInt = 0
    var scopes = [UInt: Scope]()
    var closed = false
    
    init(client: Client, token: String) {
        self.client = client
        self.token = token
        // TODO: start timer that pings at regular interval
    }
    
    // MARK: - Public interface
    public func fetch(scope: Scope, callback: (NSError?) -> ()) {
        fetch(scope, params: [String: AnyObject](), callback: callback)
    }
    
    public func fetch(scope: Scope, params: [String: AnyObject], callback: (NSError?) -> ()) {
        if closed {
            return callback(errorWithUserInfo(
                .SessionAlreadyClosed,
                [NSLocalizedDescriptionKey: "Session already closed"]))
        }
        
        let scopeFetchMessage = ScopeFetchMessage(session: self, name: scope.name, params: params)
        client.transport.sendMessage(scopeFetchMessage) {
            [weak self] (response) in
            if let this = self {
                this.scopeFetchCompleted(scope, response: response, callback: callback)
            }
        }
    }
    
    // MARK: - Internal interface
    func getNextMessageIndex() -> UInt {
        return nextMessageIndex++
    }
    
    func receivedMessage(message: Message) {
        if closed {
            return
        }
        
        let isFirstOrEphermalMessage = message.index == 0
        if message.index <= serverIndex && !isFirstOrEphermalMessage {
            // Likely due to an outgoing Ping we sent up with a low ack number 
            // that since increased by received messages from the server
            logger.info("Server resent seen message")
            return
        }
        if message.index != serverIndex + 1 && !isFirstOrEphermalMessage {
            logger.error("Received out of order message index")
            client.transport.reconnect()
            return
        }
        
        if !isFirstOrEphermalMessage {
            serverIndex = message.index
        }
        
        switch message {
        case let scopeStateMessage as ScopeStateMessage:
            if let scope = scopes[scopeStateMessage.scopeIndex] {
                if let rootModel = scope.rootModel {
                    scope.startApplyingRemote()
                    scope.applyRootFragment(scopeStateMessage.rootFragment, additionalFragments: scopeStateMessage.syncFragments)
                    scope.endApplyingRemote()
                } else {
                    logger.error("Received state message without having a root model")
                }
            } else {
                logger.error("Received state message without having local scope")
            }
        case let scopeSyncMessage as ScopeSyncMessage:
            if let scope = scopes[scopeSyncMessage.scopeIndex] {
                if let rootModel = scope.rootModel {
                    if scopeSyncMessage.syncFragments.count > 0 {
                        scope.startApplyingRemote()
                        scope.applySyncFragments(scopeSyncMessage.syncFragments)
                        scope.endApplyingRemote()
                    } else {
                        logger.error("Received sync message without fragments")
                    }
                }
            }
        default:
            break
        }
    }
    
    func scopeFetchCompleted(scope: Scope, response: [String: AnyObject], callback: (NSError?) -> ()) {
        if closed {
            return callback(errorWithUserInfo(
                .SessionBecameClosed,
                [NSLocalizedDescriptionKey: "Session became closed"]))
        }
        
        var result = response["result"] as? Bool
        var scopeIndex = response["scopeIndex"] as? UInt
        
        if result != nil && scopeIndex != nil && result! == true {
            scopeAttach(scope, scopeIndex: scopeIndex!)
            callback(nil)
        } else {
            var definiteErrorCode = 0
            
            var error = response["error"] as? [String: AnyObject]
            var errorMessage = error?["message"] as? String
            var errorSlug = error?["slug"] as? String
            
            var userInfo = [NSLocalizedDescriptionKey: "Fetch request failed"]
            if errorMessage != nil {
                userInfo[NSLocalizedFailureReasonErrorKey] = errorMessage!
            }
            if errorSlug != nil {
                userInfo[NSLocalizedFailureReasonErrorKey] = errorSlug!
            }
            
            callback(errorWithUserInfo(.SessionFetchFailed, userInfo))
        }
    }
    
    func scopeAttach(scope: Scope, scopeIndex: UInt) {
        scopes[scopeIndex] = scope
        scope.onChanges.listen(self) {
            [weak self] changeSet in
            if let definiteSelf = self {
                definiteSelf.scopeChanges(scope, atIndex: scopeIndex, syncFragments: changeSet.syncFragments)
            }
        }
    }
    
    func scopeChanges(scope: Scope, atIndex: UInt, syncFragments: [SyncFragment]) {
        if closed {
            return
        }
        
        client.transport.sendMessage(ScopeSyncMessage(session: self, scopeIndex: atIndex, syncFragments: syncFragments))
    }
    
    func close() {
        for (_, scope) in scopes {
            scope.onChanges.removeListener(self)
        }
        scopes.removeAll(keepCapacity: false)
        closed = true
    }
}
