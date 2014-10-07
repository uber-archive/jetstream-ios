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
        return "ScopeSync"
    }
    
    override var type: String {
        return ScopeSyncMessage.messageType
    }
    
    let scopeIndex: UInt
    let syncFragments: [SyncFragment]
    
    init(index: UInt, scopeIndex: UInt, syncFragments: [SyncFragment]) {
        self.scopeIndex = scopeIndex
        self.syncFragments = syncFragments
        super.init(index: index)
    }
    
    convenience init(session: Session, scopeIndex: UInt, syncFragments: [SyncFragment]) {
        self.init(index: session.getIndexForMessage(), scopeIndex: scopeIndex, syncFragments: syncFragments)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        let fragments = syncFragments.map {
            (syncFragment) -> [String: AnyObject] in
            
            return syncFragment.serialize()
        }
        
        dictionary["scopeIndex"] = scopeIndex
        dictionary["fragments"] = fragments
        
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
                syncFragments: syncFragments!)
        }
    }
}
