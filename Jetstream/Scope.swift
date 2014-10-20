//
//  Scope.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

public class Scope {
    /// A signal that fires when changes have been made to the model. Provides a array of changes
    /// since the signal last fired.
    public let onChanges = Signal<([SyncFragment])>()
    
    public var name: String
    
    /// The root model associates with the scope
    public var rootModel: ModelObject? {
        if modelObjects.count > 0 {
            return modelObjects[0]
        }
        return nil
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
                if (!this.applyingRemote) {
                    if let property = modelObject.properties[key] {
                        if (property.valueType != .Composite) {
                            var modelValue: ModelValue?
                            if (value != nil) {
                                modelValue = convertAnyObjectToModelValue(value!, property.valueType)
                            }
                            if let fragment = this.syncFragmentWithType(.Change, modelObject: modelObject) {
                                fragment.newValueForKeyFromModelObject(key, modelValue: modelValue, modelObject: modelObject)
                            }
                        }
                    }
                }
            }
        }
        
        if modelObject.parents.count > 0 {
            if (!applyingRemote) {
                self.syncFragmentWithType(.Add, modelObject: modelObject)
            }
        }
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
        modelObject.onPropertyChange.removeListener(self)
        modelObject.onDetachedFromScope.removeListener(self)
        if (!applyingRemote) {
            self.syncFragmentWithType(.Remove, modelObject: modelObject)
        }
    }
    
    func applyRootFragment(rootFragment: SyncFragment, additionalFragments:[SyncFragment]) {
        let uuids = additionalFragments.map { $0.objectUUID }
        let removals = modelHash.keys.filter { !contains(uuids, $0) && $0 != rootFragment.objectUUID }
        for removeUUID in removals {
            if let model = modelHash[removeUUID] {
                model.detach()
            }
        }
        var fragments = additionalFragments
        fragments.append(rootFragment)
        applySyncFragments(fragments, applyDefaults: true)
    }
    
    func syncFragmentWithType(type: SyncFragmentType, modelObject: ModelObject) -> SyncFragment? {
        if let fragment = syncFragmentLookup[modelObject.uuid] {
            if (type == SyncFragmentType.Remove && fragment.type == SyncFragmentType.Add) {
                // Previous add fragment was reverted by remove fragment
                removeFragment(fragment)
                return nil
            } else if (type == SyncFragmentType.Add && fragment.type == SyncFragmentType.Remove) {
                // Delete remove fragment and create new add fragment
                removeFragment(fragment)
                return addFragment(SyncFragment(type: type, modelObject: modelObject))
            }
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
        changesQueued = false
        var fragments = getAndClearSyncFragments()
        if fragments.count > 0 {
            onChanges.fire(fragments)
        }
    }
    
    // MARK: - Public API
    
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
    
    /// Applies sync fragments to the model
    ///
    /// :param: syncFragments An array of sync fragments to apply
    func applySyncFragments(syncFragments: [SyncFragment], applyDefaults: Bool = false) {
        for fragment in syncFragments {
            if let modelObject = fragment.createObjectForScopeIfNecessary(self) {
                tempModelHash[modelObject.uuid] = modelObject
            }
        }
        syncFragments.map { $0.applyChangesToScope(self, applyDefaults: applyDefaults) }
        tempModelHash.removeAll(keepCapacity: false)
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
    public func getObjectById(uuidString: String) -> ModelObject? {
        return getObjectById(NSUUID(UUIDString: uuidString))
    }
}
