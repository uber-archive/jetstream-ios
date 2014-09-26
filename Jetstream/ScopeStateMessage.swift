//
//  ScopeStateMessage.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class ScopeStateMessage: Message {
    
    class var messageType: String {
        get { return "ScopeState" }
    }
    
    override var type: String {
        get { return ScopeStateMessage.messageType }
    }
    
    var syncFragments: [SyncFragment]
    
    init(syncFragments: [SyncFragment]) {
        self.syncFragments = syncFragments
        super.init()
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()

        dictionary["fragments"] = syncFragments.map({ (syncFragment) -> [String: AnyObject] in
            return syncFragment.serialize()
        })
        
        return dictionary
    }
    
    override class func unserialize(dictionary: [String: AnyObject]) -> Message? {
        var syncFragments: [SyncFragment]?
        
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
            default:
                println("Unknown object")
            }
        }

        if (syncFragments == nil) {
            return nil
        } else {
            return ScopeStateMessage(syncFragments: syncFragments!)
        }
    }
}
