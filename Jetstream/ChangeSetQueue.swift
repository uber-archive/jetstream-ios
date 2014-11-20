//
// ChangeSetQueue.swift
// Jetstream
// 
// Copyright (c) 2014 Uber Technologies, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

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
    func addChangeSet(changeSet: ChangeSet) {
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
