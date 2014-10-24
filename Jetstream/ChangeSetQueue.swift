//
//  ChangeSetQueue.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/20/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

public class ChangeSetQueue {
    // A signal that fires whenever a change set is added to the queue
    public let onChangeSetAdded = Signal<ChangeSet>()
    
    // A signal that fires whenever the state of a change set in the queue changes
    public let onChangeSetStateChanged = Signal<(ChangeSet, ChangeSetState)>()
    
    // A signal that fires whenever a change set has been removed from the queue
    public let onChangeSetRemoved = Signal<ChangeSet>()
    
    // The number of change sets in the queue
    public var count: Int {
        return changeSets.count
    }
    
    var changeSets = [ChangeSet]()
    
    // MARK: - Private interface
    func addChageSet(changeSet: ChangeSet) {
        assert(find(changeSets, changeSet) == nil, "ChangeSet already in queue")
        
        changeSet.changeSetQueue = self
        changeSets.append(changeSet)
        onChangeSetAdded.fire(changeSet)
        
        changeSet.onStateChange.listen(self) { [weak self] state in
            if let definiteSelf = self {
                definiteSelf.onChangeSetStateChanged.fire(changeSet, state)
                if state == .Completed {
                    definiteSelf.removeChangeSet(changeSet)
                } else if state == .Reverted {
                    if let index = find(definiteSelf.changeSets, changeSet) {
                        if index < definiteSelf.changeSets.count - 1 {
                            definiteSelf.changeSets[index+1].rebaseOnChangeSet(definiteSelf.changeSets[0])
                        }
                    }
                    definiteSelf.removeChangeSet(changeSet)
                }
            }
        }
    }
    
    func removeChangeSet(changeSet: ChangeSet) {
        if let index = find(changeSets, changeSet) {
            changeSets.removeAtIndex(index)
            onChangeSetRemoved.fire(changeSet)
        }
    }
}
