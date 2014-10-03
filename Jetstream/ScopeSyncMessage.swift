//
//  ScopeSyncMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class ScopeSyncMessage: IndexedMessage {
    
    class var messageType: String {
        get { return "ScopeSync" }
    }
    
    override var type: String {
        get { return ScopeSyncMessage.messageType }
    }
    
    let scopeIndex: UInt
    let syncFragments: [SyncFragment]
    let fullState: Bool

    convenience init(session: Session, scopeIndex: UInt, syncFragments: [SyncFragment]) {
        self.init(index: session.getIndexForMessage(), scopeIndex: scopeIndex, syncFragments: syncFragments, fullState: false)
    }
    
    convenience init(session: Session, scopeIndex: UInt, syncFragments: [SyncFragment], fullState: Bool) {
        self.init(index: session.getIndexForMessage(), scopeIndex: scopeIndex, syncFragments: syncFragments, fullState: fullState)
    }
    
    init(index: UInt, scopeIndex: UInt, syncFragments: [SyncFragment], fullState: Bool) {
        self.scopeIndex = scopeIndex
        self.syncFragments = syncFragments
        self.fullState = fullState
        super.init(index: index)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        let fragments = syncFragments.map {
            (syncFragment) -> [String: AnyObject] in
            
            return syncFragment.serialize()
        }
        
        dictionary["scopeIndex"] = scopeIndex
        dictionary["fragments"] = fragments
        dictionary["fullState"] = fullState
        
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index: UInt?
        var scopeIndex: UInt?
        var syncFragments: [SyncFragment]?
        var fullState = false
        
        for (key, value) in dictionary {
            switch key {
            case "index":
                if let definiteIndex = value as? UInt {
                    index = definiteIndex
                }
            case "scopeIndex":
                if let definiteScopeIndex = value as? UInt {
                    scopeIndex = definiteScopeIndex
                }
            case "fragments":
                if let fragments = value as? [[String: AnyObject]] {
                    syncFragments = [SyncFragment]()
                    for fragment in fragments {
                        if let syncFragment = SyncFragment.unserialize(fragment) {
                            syncFragments!.append(syncFragment)
                        }
                    }
                }
            case "fullState":
                if let boolValue = value as? Bool {
                    fullState = boolValue
                }
            default:
                break
            }
        }
        
        if index == nil || scopeIndex == nil || syncFragments == nil {
            return nil
        } else {
            return ScopeSyncMessage(
                index: index!,
                scopeIndex: scopeIndex!,
                syncFragments: syncFragments!,
                fullState: fullState)
        }
    }
}
