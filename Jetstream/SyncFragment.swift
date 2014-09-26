//
//  SyncFragment.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation
import Jetstream

public enum SyncFragmentType: String {
    case Change = "change"
    case Add = "add"
    case Remove = "remove"
    case MoveChange = "movechange"
}

public class SyncFragment {

    let type: SyncFragmentType
    let objectUUID: NSUUID
    let clsName: String?
    var properties: [String: AnyObject?]?
    let parentUUID: NSUUID?
    let keyPath: String?
    
    // TODO: Return nil when not able to parse
    init(dictionary: [String: AnyObject]) {
        self.type = .Change
        self.objectUUID = NSUUID.UUID()
        self.properties = [String: AnyObject?]()
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
    
    init(type:SyncFragmentType, modelObject: ModelObject) {
        self.type = type
        self.objectUUID = modelObject.uuid
        
        if (type == .Add) {
            //self.clsName = NSStringFromClass(modelObject.dynamicType)
            self.keyPath = modelObject.parent?.keyPath
            self.properties = Dictionary<String, AnyObject>()
            applyPropertiesFromModelObject(modelObject)
        } else if (type == .Change) {
            self.properties = Dictionary<String, AnyObject>()
        } else if (type == .MoveChange) {
            self.properties = Dictionary<String, AnyObject>()
            self.keyPath = modelObject.parent?.keyPath
        }
    }

    func applyPropertiesToModelObject(modelObject: ModelObject) {
        if let definiteProperties = properties {
            for (key, value) in definiteProperties {
                modelObject.setValue(value, forKey: key)
            }
        }
    }
    
    func newValueForKey(key: String, value:AnyObject?) {
        if (properties == nil) {
            properties = [String: AnyObject]()
        }
        properties![key] = value
    }
    
    func applyPropertiesFromModelObject(modelObject: ModelObject) {
        if (properties == nil) {
            properties = [String: AnyObject]()
        }
        for (name, property) in modelObject.properties {
            if (!property.isArray) {
                let value: AnyObject? = modelObject.valueForKey(property.key)
                properties![name] = value
            }
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