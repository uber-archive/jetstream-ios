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
                let fragment = self.syncFragmentWithType(.Change, modelObject: modelObject)
                fragment.newValueForKey(keyPath, value: value)
                self.setChangeTimer()
            }
        })
        
        if let definiteParent = modelObject.parent {
            let fragment = self.syncFragmentWithType(.Add, modelObject: modelObject)
            setChangeTimer()
        }
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
        modelObject.onPropertyChange.removeListener(self)
        modelObject.onDetachedFromScope.removeListener(self)
        
        let fragment = self.syncFragmentWithType(.Remove, modelObject: modelObject)
        self.setChangeTimer()
        
        setChangeTimer()
    }
    
    func applySyncFragment(syncFragment: SyncFragment) {
        syncFragment.applyChangesToScope(self)
    }
    
    func syncFragmentWithType(type: SyncFragmentType, modelObject: ModelObject) -> SyncFragment {
        if let fragment = syncFragmentLookup[modelObject.uuid] {
            return fragment
        }
        let fragment = SyncFragment(type: type, modelObject: modelObject)
        syncFragments.append(fragment)
        syncFragmentLookup[modelObject.uuid] = fragment
        return fragment
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
