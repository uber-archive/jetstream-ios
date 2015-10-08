//
//  Scope.swift
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

@objc public class Scope: NSObject {
    /// A signal that fires when changes have been made to the model. Provides a array of changes
    /// since the signal last fired.
    public let onChanges = Signal<(ChangeSet)>()
    
    /// A signal that fires when changes have been made to the model from a remote source.
    public let onRemoteSync = Signal<Void>()
    
    /// The name of the scope.
    public private(set) var name: String
    
    /// The root model associates with the scope.
    public var root: ModelObject? {
        get {
            if modelObjects.count > 0 {
                return modelObjects[0]
            }
            return nil
        }
        set {
            if modelObjects.count == 0 {
                if let definiteNewValue = newValue {
                    definiteNewValue.setScopeAndMakeRootModel(self)
                }
            }
        }
    }
    
    var syncFragmentLookup = [NSUUID: SyncFragment]()
    var syncFragments = [SyncFragment]()
    var removedModelObjects = [ModelObject]()
    var modelObjects = [ModelObject]()
    var modelHash = [NSUUID: ModelObject]()
    var applyingRemote = false
    var changesQueued = false
    var changeInterval: NSTimeInterval
    var propertyUpdateDates = [String: NSDate]()
    
    var incomingPauseCount = 0
    typealias incomingCallback = () -> Void
    var incomingQueue = [incomingCallback]()
    
    private var tempModelHash = [NSUUID: ModelObject]()
    
    /// Constructs a scope.
    ///
    /// - parameter name: The name of the scope.
    /// - parameter changeInterval: Time interval between which to capture and fire changes without explict modifications.
    public init(name: String, changeInterval: NSTimeInterval = 0.01) {
        self.name = name
        self.changeInterval = changeInterval
    }
    
    // MARK: - Public Interface
    
    /// Retrieves all sync fragments that have been generated since this function was last called. Calling
    /// this method will clear out all sync fragments.
    ///
    /// - returns: An Array of sync fragments that have been observed in the scope.
    public func getAndClearSyncFragments() -> [SyncFragment] {
        let fragments = syncFragments
        syncFragments.removeAll(keepCapacity: false)
        syncFragmentLookup.removeAll(keepCapacity: false)
        removedModelObjects.removeAll(keepCapacity: false)
        var nonVoidFragments = [SyncFragment]()
        for fragment in fragments {
            if fragment.type == .Change &&
                (fragment.properties == nil ||
                    fragment.properties?.count == 0) {
                        continue
            }
            nonVoidFragments.append(fragment)
        }
        return nonVoidFragments
    }
    
    /// Applies sync fragments to the model.
    ///
    /// - parameter syncFragments: An array of sync fragments to apply.
    /// - parameter applyDefaults: Whether to apply default values for model objects in add fragments.
    public func applySyncFragments(syncFragments: [SyncFragment], applyDefaults: Bool = false) {
        for fragment in syncFragments {
            if let modelObject = fragment.createObjectForScopeIfNecessary(self) {
                tempModelHash[modelObject.uuid] = modelObject
            }
        }
        for syncFragment in syncFragments {
            syncFragment.applyChangesToScope(self, applyDefaults: applyDefaults)
        }
        tempModelHash.removeAll(keepCapacity: false)
        if applyingRemote {
            onRemoteSync.fire()
        }
    }
    
    /// Retrieve an object by it's uuid.
    ///
    /// - parameter The: uuid of the object to get.
    /// - returns: The model object with the given uuid.
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        if let modelObject = modelHash[uuid] {
            return modelObject
        }
        return tempModelHash[uuid]
    }
    
    /// Retrieve an object by it's uuid.
    ///
    /// - parameter The: string representing the uuid of the object to get.
    /// - returns: The model object with the given uuid.
    public func getObjectByIdString(uuidString: String) -> ModelObject? {
        if let uuid = NSUUID(UUIDString: uuidString) {
            return getObjectById(uuid)
        }
        return nil
    }
    
    public func pauseIncomingMessages() {
        incomingPauseCount++
    }
    
    public func resumeIncomingMessages() {
        assert(incomingPauseCount > 0, "Uneven distribution of pause vs. resume calls")
        incomingPauseCount--
        if incomingPauseCount == 0 {
            applyingRemote = true
            for callback in incomingQueue {
                callback()
            }
            applyingRemote = false
            incomingQueue.removeAll(keepCapacity: false)
        }
    }
    
    /// Modify the scope with an explict set of changes.
    ///
    /// - parameter changes: The set of changes to send together.
    public func modify(changes: () -> Void) -> ChangeSet {
        return createChangeSet(false, procedure: nil, constraints: nil, changes: changes)
    }

    /// Modify the scope with an explict set of changes and request it be applied atomically.
    ///
    /// - parameter changes: The set of changes to send together.
    public func modifyAtomically(changes: () -> Void) -> ChangeSet {
        return createChangeSet(true, procedure: nil, constraints: nil, changes: changes)
    }

    /// Modify the scope with an explict set of changes and procedure, it will also request to be applied atomically.
    ///
    /// - parameter procedure: The name of the procedure to call with the changes.
    /// - parameter constraints: Optionally the constraints the changes should adhere to perform validation.
    /// - parameter changes: The set of changes to send together.
    public func modifyWithProcedure(procedure: String, constraints: [Constraint]?, changes: () -> Void) -> ChangeSet {
        return createChangeSet(true, procedure: procedure, constraints: constraints, changes: changes)
    }

    // MARK: - Internal Interface
    
    func createChangeSet(atomic: Bool, procedure: String?, constraints: [Constraint]?, changes: () -> Void) -> ChangeSet {
        sendChanges()
        changes()
        let syncFragments = getAndClearSyncFragments()
        let changeSet = ChangeSet(syncFragments: syncFragments, procedure: procedure, atomic: atomic, scope: self)
        if let definiteConstraints = constraints {
            if !Constraint.matchesAllConstraints(definiteConstraints, syncFragments: syncFragments) {
                changeSet.revertOnScope(self)
                return changeSet
            }
        }
        if changeSet.syncFragments.count > 0 {
            onChanges.fire(changeSet)
        }
        return changeSet
    }
    
    func startApplyingRemote(callback: incomingCallback) {
        if incomingPauseCount == 0 {
            applyingRemote = true
            callback()
            applyingRemote = false
        } else {
            incomingQueue.append(callback)
        }
    }
    
    func addModelObject(modelObject: ModelObject) {
        modelObjects.append(modelObject)
        modelHash[modelObject.uuid] = modelObject
        
        modelObject.onPropertyChange.listen(self) { [weak self] (key, oldValue, value) -> () in
            if let this = self {
                if this.applyingRemote {
                    return
                }
                if let property = modelObject.properties[key] {
                    if property.dontSync {
                        return
                    }
                    if property.minUpdateInterval > 0 {
                        let now = NSDate()
                        let objectKeyIdentifier = "\(modelObject.uuid.UUIDString)_\(key)"
                        if let date = this.propertyUpdateDates[objectKeyIdentifier] {
                            if now.timeIntervalSinceDate(date) < property.minUpdateInterval {
                                return
                            }
                        }
                        this.propertyUpdateDates[objectKeyIdentifier] = now
                    }
                    
                    var modelValue: ModelValue?
                    if value != nil {
                        modelValue = convertAnyObjectToModelValue(value!, type: property.valueType)
                    }
                    if let fragment = this.syncFragmentWithType(.Change, modelObject: modelObject) {
                        fragment.newValueForKeyFromModelObject(key, newValue: modelValue, oldValue: oldValue, modelObject: modelObject)
                    }
                    
                }
            }
        }
        
        if modelObject.parents.count > 0 {
            if let index = removedModelObjects.indexOf(modelObject) {
                removedModelObjects.removeAtIndex(index)
            } else if !applyingRemote {
                self.syncFragmentWithType(.Add, modelObject: modelObject)
            }
        }
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
        removedModelObjects.append(modelObject)
        modelObject.onPropertyChange.removeListener(self)
        modelObject.onDetachedFromScope.removeListener(self)
        if let fragment = syncFragmentLookup[modelObject.uuid] {
            removeFragment(fragment)
        }
    }
    
    func applyFullStateFromFragments(fragments:[SyncFragment], rootUUID: NSUUID) {
        if let definiteRoot = root {
            updateUUIDForModel(definiteRoot, uuid: rootUUID)
            
            let uuids = fragments.map { $0.objectUUID }
            let removals = modelHash.keys.filter { !uuids.contains($0) && $0 != rootUUID }
            for removeUUID in removals {
                if let model = modelHash[removeUUID] {
                    model.detach()
                }
            }
            applySyncFragments(fragments, applyDefaults: true)
            propertyUpdateDates.removeAll(keepCapacity: false)
        }
    }
    
    func syncFragmentWithType(type: SyncFragmentType, modelObject: ModelObject) -> SyncFragment? {
        if let fragment = syncFragmentLookup[modelObject.uuid] {
            setChangeTimer()
            return fragment
        }
        return addFragment(SyncFragment(type: type, modelObject: modelObject))
    }
    
    func updateUUIDForModel(modelObject: ModelObject, uuid: NSUUID) {
        if modelHash[modelObject.uuid] != nil {
            modelHash.removeValueForKey(modelObject.uuid)
            modelHash[uuid] = modelObject
            modelObject.uuid = uuid
        }
    }
    
    private func addFragment(fragment: SyncFragment) -> SyncFragment {
        syncFragments.append(fragment)
        syncFragmentLookup[fragment.objectUUID] = fragment
        self.setChangeTimer()
        return fragment
    }
    
    private func removeFragment(fragment: SyncFragment) {
        if let index = syncFragments.indexOf(fragment) {
            syncFragments.removeAtIndex(index)
            syncFragmentLookup.removeValueForKey(fragment.objectUUID)
        }
    }
    
    private func setChangeTimer() {
        if !changesQueued {
            changesQueued = true
            delay(changeInterval) { [weak self] in
                if let this = self {
                    this.sendChanges()
                }
            }
        }
    }

    private func sendChanges() {
        if changesQueued {
            changesQueued = false
            let syncFragments = getAndClearSyncFragments()
            if syncFragments.count > 0 {
                let changeSet = ChangeSet(syncFragments: syncFragments, scope: self)
                if changeSet.syncFragments.count > 0 {
                    onChanges.fire(changeSet)
                }
            }
        }
    }
}
