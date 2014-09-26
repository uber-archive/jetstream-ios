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
    
    var syncFragments = [NSUUID: SyncFragment]()
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
        var syncFragment = SyncFragment(type: .Add, modelObject: modelObject)
        syncFragments[modelObject.uuid] = syncFragment
        setChangeTimer()
        
        modelObject.onPropertyChange.listen(self, callback: { [unowned self] (keyPath, value) -> Void in
            let fragment = self.syncFragmentWithType(SyncFragmentType.Change, modelObject: modelObject)
            fragment.newValueForKey(keyPath, value: value)
            self.setChangeTimer()
        })
    }
    
    func removeModelObject(modelObject: ModelObject) {
        modelObjects = modelObjects.filter { $0 != modelObject }
        modelHash.removeValueForKey(modelObject.uuid)
        modelObject.onPropertyChange.removeListener(self)
        setChangeTimer()
    }
    
    func applySyncFragment(syncFragment: SyncFragment) {
        syncFragment.applyChangesToScope(self)
    }
    
    func syncFragmentWithType(type: SyncFragmentType, modelObject: ModelObject) -> SyncFragment {
        if let fragment = syncFragments[modelObject.uuid] {
            return fragment
        }
        let fragment = SyncFragment(type: type, modelObject: modelObject)
        syncFragments[modelObject.uuid] = fragment
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
        let fragments = syncFragments.values.array
        syncFragments.removeAll(keepCapacity: false)
        return fragments
    }
    
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        return modelHash[uuid]
    }
    
    public func getObjectById(uuidString: String) -> ModelObject? {
        return getObjectById(NSUUID(UUIDString: uuidString))
    }
}
