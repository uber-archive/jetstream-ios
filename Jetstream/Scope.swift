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
    
    public var name: String
    
    /// The root model associates with the scope
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
    var modelObjects = [ModelObject]()
    var modelHash = [NSUUID: ModelObject]()
    var applyingRemote = false
    var changesQueued = false
    var changeInterval: NSTimeInterval
    
    private var tempModelHash = [NSUUID: ModelObject]()
    
    public init(name: String, changeInterval: NSTimeInterval = 0.01) {
        self.name = name
        self.changeInterval = changeInterval
    }
    
    // MARK: - Public Interface
    
    /// Retrieves all sync fragments that have been generated since this function was last called. Calling
    /// this method will clear out all sync fragments.
    ///
    /// :returns: An Array of sync fragments that have been observed in the scope.
    public func getAndClearSyncFragments() -> [SyncFragment] {
        let fragments = syncFragments
        syncFragments.removeAll(keepCapacity: false)
        syncFragmentLookup.removeAll(keepCapacity: false)
        return fragments.filter { (fragment) -> Bool in
            // Filter out any empty change fragments
            if fragment.type == .Change &&
                (fragment.properties == nil ||
                    fragment.properties?.count == 0) {
                        return false
            }
            return true
        }
    }
    
    /// Applies sync fragments to the model.
    ///
    /// :param: syncFragments An array of sync fragments to apply.
    /// :param: applyDefaults Whether to apply default values for model objects in add fragments.
    public func applySyncFragments(syncFragments: [SyncFragment], applyDefaults: Bool = false) {
        for fragment in syncFragments {
            if let modelObject = fragment.createObjectForScopeIfNecessary(self) {
                tempModelHash[modelObject.uuid] = modelObject
            }
        }
        syncFragments.map { $0.applyChangesToScope(self, applyDefaults: applyDefaults) }
        tempModelHash.removeAll(keepCapacity: false)
        if applyingRemote {
            onRemoteSync.fire()
        }
    }
    
    /// Retrieve an object by it's uuid.
    ///
    /// :param: The uuid of the object to get.
    /// :returns: The model object with the given uuid.
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        if let modelObject = modelHash[uuid] {
            return modelObject
        }
        return tempModelHash[uuid]
    }
    
    /// Retrieve an object by it's uuid.
    ///
    /// :param: The string representing the uuid of the object to get.
    /// :returns: The model object with the given uuid.
    public func getObjectByIdString(uuidString: String) -> ModelObject? {
        if let uuid = NSUUID(UUIDString: uuidString) {
            return getObjectById(uuid)
        }
        return nil
    }
    
    public func createAtomicChangeSet(changes: () -> Void) -> ChangeSet {
        sendChanges()
        changes()
        var syncFragments = getAndClearSyncFragments()
        let changeSet = ChangeSet(syncFragments: syncFragments, atomic: true, scope: self)
        onChanges.fire(changeSet)
        return changeSet
    }

    // MARK: - Internal Interface
    func startApplyingRemote() {
        applyingRemote = true
    }
    
    func endApplyingRemote() {
        applyingRemote = false
    }
    
    func addModelObject(modelObject: ModelObject) {
        modelObjects.append(modelObject)
        modelHash[modelObject.uuid] = modelObject
        
        modelObject.onPropertyChange.listen(self) { [weak self] (key, oldValue, value) -> () in
            if let this = self {
                if !this.applyingRemote {
                    if let property = modelObject.properties[key] {
                        if !property.dontSync {
                            var modelValue: ModelValue?
                            if value != nil {
                                modelValue = convertAnyObjectToModelValue(value!, property.valueType)
                            }
                            if let fragment = this.syncFragmentWithType(.Change, modelObject: modelObject) {
                                fragment.newValueForKeyFromModelObject(key, newValue: modelValue, oldValue: oldValue, modelObject: modelObject)
                            }
                        }
                    }
                }
            }
        }
        
        if modelObject.parents.count > 0 {
            if !applyingRemote {
                self.syncFragmentWithType(.Add, modelObject: modelObject)
            }
        }
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
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
            let removals = modelHash.keys.filter { !contains(uuids, $0) && $0 != rootUUID }
            for removeUUID in removals {
                if let model = modelHash[removeUUID] {
                    model.detach()
                }
            }
            applySyncFragments(fragments, applyDefaults: true)
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
        if let index = find(syncFragments, fragment) {
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
            var syncFragments = getAndClearSyncFragments()
            if syncFragments.count > 0 {
                let changeSet = ChangeSet(syncFragments: syncFragments, atomic: false, scope: self)
                onChanges.fire(changeSet)
            }
        }
    }
}
