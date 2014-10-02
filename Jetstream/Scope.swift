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
    
    var syncFragmentLookup = [NSUUID: SyncFragment]()
    var syncFragments = [SyncFragment]()
    var modelObjects = [ModelObject]()
    var modelHash = [NSUUID: ModelObject]()
    var timer: NSTimer?
    var changeInterval: NSTimeInterval
    
    public init(name: String, changeInterval: NSTimeInterval = 0.01) {
        self.name = name
        self.changeInterval = changeInterval
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
                    fragment.newValueForKey(keyPath, value: value)
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
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(changeInterval, target: self, selector: Selector("sendChanges"), userInfo: nil, repeats: false)
        }
    }

    dynamic private func sendChanges() {
        timer = nil
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
        return fragments
    }
    
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        return modelHash[uuid]
    }
    
    public func getObjectById(uuidString: String) -> ModelObject? {
        return getObjectById(NSUUID(UUIDString: uuidString))
    }
}
