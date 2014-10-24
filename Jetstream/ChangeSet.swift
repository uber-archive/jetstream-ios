//
//  ChangeSet.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/20/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

public enum ChangeSetState {
    case Syncing
    case Completed
    case Reverted
}

public class ChangeSet: Equatable {
    /// A signal that fires whenever the state of the change set changes.
    public let onStateChange = Signal<ChangeSetState>()
    
    /// The current state of the change set.
    public private(set) var state: ChangeSetState = .Syncing {
        didSet {
            if state != oldValue {
                onStateChange.fire(state)
            }
        }
    }
    
    /// The sync fragments associated with the ChangeSet
    public let syncFragments: [SyncFragment]
    
    var changeSetQueue: ChangeSetQueue?
    var touches = [ModelObject: [String: AnyObject]]()
    
    public init(syncFragments: [SyncFragment], scope: Scope) {
        self.syncFragments = syncFragments
        
        for syncFragment in syncFragments {
            if syncFragment.type == .Change {
                if let modelObject = scope.getObjectById(syncFragment.objectUUID) {
                    var properties = touches[modelObject] != nil ? touches[modelObject]! : [String: AnyObject]()
                    
                    if let definiteProperties = syncFragment.properties {
                        for (key, _) in definiteProperties {
                            if let value: AnyObject = syncFragment.originalProperties?[key] {
                                properties[key] = value
                            }
                        }
                    }
                    touches[modelObject] = properties
                }
            }
        }
    }
    
    func rebaseOnChangeSet(changeSet: ChangeSet) {
        for (rebaseModelObject, rebaseProperties) in changeSet.touches {
            for (modelObject, properties) in touches {
                if modelObject.uuid != rebaseModelObject.uuid {
                    continue
                }
                for (key, value) in rebaseProperties {
                    let valueAsAnyObject: AnyObject = value
                    touches[modelObject]![key] = valueAsAnyObject
                }
            }
        }
    }
    
    func removeTouchesFromChangeSet(changeSet: ChangeSet) {
        for (overrideModelObject, overrideProperties) in changeSet.touches {
            for (modelObject, properties) in touches {
                if modelObject.uuid != overrideModelObject.uuid {
                    continue
                }
                for (key, value) in overrideProperties {
                    touches[modelObject]!.removeValueForKey(key)
                }
                if touches[modelObject]!.count == 0 {
                    touches.removeValueForKey(modelObject)
                }
            }
        }
    }
    
    func touchesModelObject(modelObject: ModelObject, key: String) -> Bool {
        if touches[modelObject] != nil {
            return touches[modelObject]![key] != nil
        }
        return false
    }
    
    func revert(scope: Scope) {
        var outstandingChangeSets = [ChangeSet]()
        if let definiteChangeSetQueue = changeSetQueue {
            if let index = find(definiteChangeSetQueue.changeSets, self) {
                for i in index + 1..<definiteChangeSetQueue.changeSets.count {
                    outstandingChangeSets.append(definiteChangeSetQueue.changeSets[i])
                }
            }
        }
        for (modelObject, properties) in touches {
            for (key, value) in properties {
                if outstandingChangeSets.reduce(false, combine: { (touches, changeSet) -> Bool in
                    return touches || changeSet.touchesModelObject(modelObject, key: key)
                }) == false {
                    if value !== NSNull() {
                        modelObject.setValue(value, forKey: key)
                    } else {
                        modelObject.setValue(nil, forKey: key)
                    }
                }
            }
        }
        state = .Reverted
    }
    
    func completed() {
        state = .Completed
    }
}

public func ==(lhs: ChangeSet, rhs: ChangeSet) -> Bool {
    return lhs === rhs
}

