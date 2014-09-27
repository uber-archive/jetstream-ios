//
//  ScopeSyncMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class ScopeSyncMessage: Message {
    
    class var messageType: String {
        get { return "ScopeSync" }
    }
    
    override var type: String {
        get { return ScopeSyncMessage.messageType }
    }
    
    var syncFragments: [SyncFragment]
    let fullState: Bool
    
    init(syncFragments: [SyncFragment], fullState: Bool) {
        self.syncFragments = syncFragments
        self.fullState = fullState
        super.init()
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        
        dictionary["fragments"] = syncFragments.map({ (syncFragment) -> [String: AnyObject] in
            return syncFragment.serialize()
        })
        dictionary["fullState"] = fullState
        
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var syncFragments: [SyncFragment]?
        var fullState = false
        
        for (key, value) in dictionary {
            switch key {
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
                // TODO: Log error
                println("Unknown object")
            }
        }
        
        if (syncFragments == nil) {
            return nil
        } else {
            return ScopeSyncMessage(syncFragments: syncFragments!, fullState: fullState)
        }
    }
}
