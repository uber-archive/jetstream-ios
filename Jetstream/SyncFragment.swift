//
//  SyncFragment.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation
import Jetstream

enum SyncFragmentType: String {
    case Change = "change"
    case Add = "add"
    case Remove = "remove"
    case MoveChange = "movechange"
}

class SyncFragment {

    let type: SyncFragmentType
    let objectUUID: NSUUID
    let clsName: String
    let properties: Dictionary<String, AnyObject>
    let parentUUID: NSUUID?
    let keyPath: String?
    
    // TODO: Return nil when not able to parse
    init(dictionary: Dictionary<String, AnyObject>) {
        self.type = .Change
        self.objectUUID = NSUUID.UUID()
        self.properties = Dictionary<String, AnyObject>()
        self.clsName = ""
        self.keyPath = ""
        
        for (key, value) in dictionary {
            switch key {
            case "type":
                if let valueAsString = value as? String {
                    if let definiteType = SyncFragmentType.fromRaw(valueAsString) {
                        self.type = definiteType
                    }
                }
            case "uuid":
                if let valueAsString = value as? String {
                    self.objectUUID = NSUUID(UUIDString: valueAsString)
                }
            case "properties":
                if let properties = value as? Dictionary<String, AnyObject> {
                    self.properties = properties
                }
            case "clsName":
                if let valueAsString = value as? String {
                    self.clsName = valueAsString
                }
            case "keyPath":
                if let valueAsString = value as? String {
                    self.keyPath = valueAsString
                }
            case "parent":
                if let valueAsString = value as? String {
                    self.parentUUID = NSUUID(UUIDString: valueAsString)
                }
            default:
                // TODO: Log error
                println("unused value")
            }
        }
    }

    func applyPropertiesToModelObject(modelObject: ModelObject) {
        for (key, value) in properties {
            modelObject.setValue(value, forKey: key)
        }
    }
    
    func applyChangesToScope(scope: Scope) {
        switch type {
        case .Change:
            if let modelObject = scope.getObjectById(objectUUID) {
                applyPropertiesToModelObject(modelObject)
            }
        case .Add:
            if let parentObject = scope.getObjectById(objectUUID) {
                if let modelObject = JTSObjectFactory.create(clsName) as? ModelObject {
                    applyPropertiesToModelObject(modelObject)
                    if let definiteKeyPath = keyPath {
                        parentObject.setValue(modelObject, forKey: definiteKeyPath)
                    }
                }
            }
        case .Remove:
            if let modelObject = scope.getObjectById(objectUUID) {
                modelObject.parent = nil
            }
        case .MoveChange:
            if let modelObject = scope.getObjectById(objectUUID) {
                applyPropertiesToModelObject(modelObject)
                if let definiteParentUUID = parentUUID {
                    if let parentObject = scope.getObjectById(definiteParentUUID) {
                        if let definiteKeyPath = keyPath {
                            parentObject.setValue(modelObject, forKey: definiteKeyPath)
                        }
                    }
                }
            }
        }
    }
}