//
//  ScopeStateMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class ScopeStateMessage: IndexedMessage {
    
    class var messageType: String {
        return "ScopeState"
    }
    
    let scopeIndex: UInt
    let rootFragment: SyncFragment
    let syncFragments: [SyncFragment]
    
    init(index: UInt, scopeIndex: UInt, rootFragment: SyncFragment, syncFragments: [SyncFragment]) {
        self.scopeIndex = scopeIndex
        self.rootFragment = rootFragment
        self.syncFragments = syncFragments
        super.init(index: index)
    }
    
    convenience init(session: Session, scopeIndex: UInt, rootFragment: SyncFragment, syncFragments: [SyncFragment]) {
        self.init(index: session.getIndexForMessage(), scopeIndex: scopeIndex, rootFragment: rootFragment, syncFragments: syncFragments)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        let fragments = syncFragments.map {
            (syncFragment) -> [String: AnyObject] in
            
            return syncFragment.serialize()
        }
        
        dictionary["scopeIndex"] = scopeIndex
        dictionary["rootFragment"] = rootFragment.serialize()
        dictionary["fragments"] = fragments
        
        return dictionary
    }
    
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var index: UInt?
        var scopeIndex: UInt?
        var rootFragment: SyncFragment!
        var syncFragments = [SyncFragment]()
        
        
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
                            syncFragments.append(syncFragment)
                        }
                    }
                }
            case "rootFragment":
                if let fragment = value as? [String: AnyObject] {
                    if let syncFragment = SyncFragment.unserialize(fragment) {
                        if (syncFragment.type == SyncFragmentType.Root) {
                            rootFragment = syncFragment
                        } else {
                            return nil
                        }
                    }
                }
            default:
                break
            }
        }
        
        if index == nil || scopeIndex == nil || rootFragment == nil {
            return nil
        } else {
            return ScopeStateMessage(
                index: index!,
                scopeIndex: scopeIndex!,
                rootFragment: rootFragment,
                syncFragments: syncFragments)
        }
    }
}
