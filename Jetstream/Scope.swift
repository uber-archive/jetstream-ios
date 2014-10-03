//
//  Scope.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

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
        
        modelObject.onPropertyChange.listen(self, callback: { [unowned self] (keyPath, oldValue, value) -> Void in
            let oldModelObject = oldValue as? ModelObject
            let newModelObject = value as? ModelObject
            
            if (oldModelObject == nil && newModelObject == nil) {
                // Only create change fragments for changes that don't affect child Model Objects
                if let fragment = self.syncFragmentWithType(.Change, modelObject: modelObject) {
                    fragment.newValueForKeyFromModelObject(keyPath, value: value, modelObject: modelObject)
                }
            }
        })
        
        if let definiteParent = modelObject.parent {
            self.syncFragmentWithType(.Add, modelObject: modelObject)
        }
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
        modelObject.onPropertyChange.removeListener(self)
        modelObject.onDetachedFromScope.removeListener(self)
        self.syncFragmentWithType(.Remove, modelObject: modelObject)
    }
    
    func applySyncFragment(syncFragment: SyncFragment) {
        syncFragment.applyChangesToScope(self)
    }
    
    func applySyncFragments(syncFragments: [SyncFragment]) {
        syncFragments.map { self.applySyncFragment($0) }
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
            // TODO: Support movechange
            
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
        if !applyingRemote {
            syncFragments.append(fragment)
            syncFragmentLookup[fragment.objectUUID] = fragment
            self.setChangeTimer()
        }
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
            delay(changeInterval) { [unowned self] in
                self.sendChanges()
            }
        }
    }

    dynamic private func sendChanges() {
        changesQueued = false
        var fragments = getAndClearSyncFragments()
        if fragments.count > 0 {
            onChanges.fire(fragments)
        }
    }
    
    // MARK: - Public API
    
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
    
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        return modelHash[uuid]
    }
    
    public func getObjectById(uuidString: String) -> ModelObject? {
        return getObjectById(NSUUID(UUIDString: uuidString))
    }
}
