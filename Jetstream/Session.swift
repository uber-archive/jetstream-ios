//
//  Session.swift
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
import UIKit

public class Session {
    /// The token of the session
    public let token: String
    
    let logger = Logging.loggerFor("Session")
    let client: Client
    var nextMessageIndex: UInt = 1
    var serverIndex: UInt = 0
    var scopes = [UInt: (Scope, [String: AnyObject])]()
    var closed = false
    let changeSetQueue = ChangeSetQueue()
    
    init(client: Client, token: String) {
        self.client = client
        self.token = token
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
                    definiteSelf.scopeAttach(scope, scopeIndex: scopeFetchReply.scopeIndex!, params: params)
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
    
    func receivedMessage(message: NetworkMessage) {
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
            if let scope = scopes[scopeStateMessage.scopeIndex]?.0 {
                if scope.root != nil {
                    scope.startApplyingRemote {
                        scope.applyFullStateFromFragments(scopeStateMessage.syncFragments, rootUUID: scopeStateMessage.rootUUID)
                    }
                } else {
                    logger.error("Received state message without having a root model")
                }
            } else {
                logger.error("Received state message without having local scope")
            }
        case let scopeSyncMessage as ScopeSyncMessage:
            if let scope = scopes[scopeSyncMessage.scopeIndex]?.0 {
                if scope.root != nil {
                    if scopeSyncMessage.syncFragments.count > 0 {
                        scope.startApplyingRemote {
                            scope.applySyncFragments(scopeSyncMessage.syncFragments)
                        }
                    } else {
                        logger.error("Received sync message without fragments")
                    }
                }
            }
        default:
            break
        }
    }
    
    func scopeAttach(scope: Scope, scopeIndex: UInt, params: [String: AnyObject] = [String: AnyObject]()) {
        scopes[scopeIndex] = (scope, params)
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
        changeSetQueue.addChangeSet(changeSet)
        client.transport.sendMessage(ScopeSyncMessage(session: self, scopeIndex: atIndex, procedure: changeSet.procedure, atomic: changeSet.atomic, syncFragments: changeSet.syncFragments)) { [weak self] reply in
            if let definiteSelf = self {
                if let syncReply = reply as? ScopeSyncReplyMessage {
                    changeSet.processFragmentReplies(syncReply.fragmentReplies, scope: scope)
                } else {
                    changeSet.revertOnScope(scope)
                }
            }
        }
    }
    
    func close() {
        for (_, scope) in scopes {
            scope.0.onChanges.removeListener(self)
        }
        scopes.removeAll(keepCapacity: false)
        closed = true
    }
}
