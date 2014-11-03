//
//  Session.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import UIKit

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
            if let definiteSelf = self {
                if let scopeFetchReply = response as? ScopeFetchReplyMessage {
                    if scopeFetchReply.error != nil {
                        return callback(scopeFetchReply.error)
                    }
                    if scopeFetchReply.scopeIndex == nil {
                        return callback(error(.ScopeFetchError, localizedDescription: "Undefined scope index"))
                    }
                    
                    if definiteSelf.closed {
                        return callback(error(.SessionBecameClosed, localizedDescription: "Session became closed"))
                    }
                    definiteSelf.scopeAttach(scope, scopeIndex: scopeFetchReply.scopeIndex!)
                    callback(nil)
                } else {
                    callback(error(.ScopeFetchError, localizedDescription: "Invalid reply message"))
                }
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
    
    func scopeAttach(scope: Scope, scopeIndex: UInt) {
        scopes[scopeIndex] = scope
        scope.onChanges.listen(self) {
            [weak self] changeSet in
            if let definiteSelf = self {
                definiteSelf.scopeChanges(scope, atIndex: scopeIndex, changeSet: changeSet)
            }
        }
    }
    
    func scopeChanges(scope: Scope, atIndex: UInt, changeSet: ChangeSet) {
        if closed {
            return
        }
        client.transport.sendMessage(ScopeSyncMessage(session: self, scopeIndex: atIndex, syncFragments: changeSet.syncFragments)) { [weak self] reply in
            if let definiteSelf = self {
                if let syncReply = reply as? ScopeSyncReplyMessage {
                    changeSet.applyFragmentResponses(syncReply.fragmentReplies, scope: scope)
                } else {
                    changeSet.revert(scope)
                }
            }
        }
    }
    
    func close() {
        for (_, scope) in scopes {
            scope.onChanges.removeListener(self)
        }
        scopes.removeAll(keepCapacity: false)
        closed = true
    }
}
