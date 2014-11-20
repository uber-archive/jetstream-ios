//
//  ChangeSet.swift
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
import Signals

public enum ChangeSetState {
    case Syncing
    case Completed
    case PartiallyReverted
    case Reverted
}

public class ChangeSet: Equatable {
    /// A signal that fires whenever the state of the change set changes.
    public let onStateChange = Signal<ChangeSetState>()
    public let onCompletion = Signal<Void>()
    public let onError = Signal<NSError>()
    
    /// The current state of the change set.
    public private(set) var state: ChangeSetState = .Syncing {
        didSet {
            if state != oldValue {
                onStateChange.fire(state)
            }
        }
    }
    
    /// Whether the ChangeSet is atomic.
    public private(set) var atomic: Bool = false
    
    /// The sync fragments associated with the ChangeSet.
    public let syncFragments: [SyncFragment]
    
    var changeSetQueue: ChangeSetQueue?
    var touches = [ModelObject: [String: AnyObject]]()
    
    var pendingChangeSets: [ChangeSet] {
        if let definiteChangeSetQueue = changeSetQueue {
            if let index = find(definiteChangeSetQueue.changeSets, self) {
                return [ChangeSet](definiteChangeSetQueue.changeSets[index + 1..<definiteChangeSetQueue.count])
            }
        }
        return [ChangeSet]()
    }
    
    /// Constructs the ChangeSet.
    ///
    /// :param: syncFragments An array of sync fragments that make up the ChangeSet.
    /// :param: atomic Whether the ChangeSet should be applied atomically (either all fragments are applied sucessfully or none are applied successfully).
    /// :param: scope The scope of the change set.
    public init(syncFragments: [SyncFragment], atomic: Bool, scope: Scope) {
        self.syncFragments = syncFragments
        self.atomic = atomic
        
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
    
    // MARK: - Public Interface
    
    /// Invokes a callback whenever the ChangeSet has completed synchronizing with the Jetstream server. For this to occur, the scope of the ChangeSet
    /// needs to have a Client that transmits the ChangeSet to a Jetstream server.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: callback A closure that gets executed whenever any property or collection on the object has changed. The closure will be called
    /// with an optional error argument, which describes what went wrong applying the ChangeSet on the Jetstream server.
    /// :returns: A function that cancels the observation when invoked.
    public func observeCompletion(observer: AnyObject, callback: (error: NSError?) -> Void) -> CancelObserver {
        let listener = onCompletion.listenOnce(observer) { callback(error: nil) }
        let errorListener = onError.listenOnce(observer) { error in callback(error: error) }
        return {
            listener.cancel()
            errorListener.cancel()
        }
    }
    
    // MARK: - Internal Interface
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
    
    func processFragmentReplies(fragmentReplies: [SyncFragmentReply], scope: Scope) {
        if fragmentReplies.count != syncFragments.count {
            Logging.loggerFor("Sync").error("Fragment mismatch, reverting ChangeSet")
            revertOnScope(scope)
        } else {
            var error: NSError?
            var index = 0
            for reply in fragmentReplies {
                let syncFragment = syncFragments[index]
                if !reply.accepted {
                    // TODO: Should gather up failed fragments in the errors userInfo
                    error = errorWithUserInfo(.SyncFragmentApplyError, [NSLocalizedDescriptionKey: "Failed to apply sync fragments"])
                    
                    if let modelObject = scope.getObjectById(syncFragment.objectUUID) {
                        if syncFragment.type != .Change || syncFragment.properties == nil {
                            continue
                        }
                        for key in syncFragment.properties!.keys {
                            if let value: AnyObject = touches[modelObject]?[key] {
                                setProperty(key, onModelObject: modelObject, toValue: value)
                            }
                        }
                    }
                    index++
                }
                if let modifications = reply.modifications {
                    if let modelObject = scope.getObjectById(syncFragment.objectUUID) {
                        for (key, value) in modifications {
                            setProperty(key, onModelObject: modelObject, toValue: value)
                        }
                    }
                }
            }
            if error == nil {
                completed()
            } else {
                let allFailed: Bool = fragmentReplies.reduce(true) { return $0 && $1.accepted }
                if allFailed {
                    state = .Reverted
                } else {
                    state = .PartiallyReverted
                }
                onError.fire(error!)
            }
        }
    }
    
    func revertOnScope(scope: Scope) {
        for (modelObject, properties) in touches {
            for (key, value) in properties {
                setProperty(key, onModelObject: modelObject, toValue: value)
            }
        }
        state = .Reverted
        
        onError.fire(errorWithUserInfo(
            .SyncFragmentApplyError,
            [NSLocalizedDescriptionKey: "Failed to apply change set"]))
    }
    
    func setProperty(key: String, onModelObject modelObject: ModelObject, toValue value: AnyObject) {
        if !pendingChangesTouchKeyOnModelObject(modelObject, key: key) {
            if value !== NSNull() {
                modelObject.setValue(value, forKey: key)
            } else {
                modelObject.setValue(nil, forKey: key)
            }
        }
    }
    
    func pendingChangesTouchKeyOnModelObject(modelObject: ModelObject, key: String) -> Bool {
        return pendingChangeSets.reduce(false) { (touches, changeSet) -> Bool in
            return touches || changeSet.touchesModelObject(modelObject, key: key)
        }
    }
    
    func completed() {
        state = .Completed
        onCompletion.fire()
    }
}

public func ==(lhs: ChangeSet, rhs: ChangeSet) -> Bool {
    return lhs === rhs
}
