//
//  ScopeStateMessage.swift
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

class ScopeStateMessage: NetworkMessage {
    class var messageType: String {
        return "ScopeState"
    }
    
    let scopeIndex: UInt
    let rootUUID: NSUUID
    let syncFragments: [SyncFragment]
    
    init(index: UInt, scopeIndex: UInt, rootUUID: NSUUID, syncFragments: [SyncFragment]) {
        self.scopeIndex = scopeIndex
        self.rootUUID = rootUUID
        self.syncFragments = syncFragments
        super.init(index: index)
    }
    
    convenience init(session: Session, scopeIndex: UInt, rootUUID: NSUUID, syncFragments: [SyncFragment]) {
        self.init(index: session.getNextMessageIndex(), scopeIndex: scopeIndex, rootUUID: rootUUID, syncFragments: syncFragments)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        let fragments = syncFragments.map {
            (syncFragment) -> [String: AnyObject] in
            
            return syncFragment.serialize()
        }
        
        dictionary["scopeIndex"] = scopeIndex
        dictionary["rootUUID"] = rootUUID.UUIDString.lowercaseString
        dictionary["fragments"] = fragments
        
        return dictionary
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> NetworkMessage? {
        var index: UInt?
        var scopeIndex: UInt?
        var rootUUID: NSUUID?
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
            case "rootUUID":
                if let UUIDString = value as? String {
                    if let UUID = NSUUID(UUIDString: UUIDString) {
                        rootUUID = UUID
                    }
                }
            default:
                break
            }
        }
        
        if index == nil || scopeIndex == nil || rootUUID == nil || syncFragments.count < 1 {
            return nil
        } else {
            return ScopeStateMessage(
                index: index!,
                scopeIndex: scopeIndex!,
                rootUUID: rootUUID!,
                syncFragments: syncFragments)
        }
    }
}
