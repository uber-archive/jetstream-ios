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

private var classPrefix: String?

public class SyncFragment {

    let type: SyncFragmentType
    let objectUUID: NSUUID
    let clsName: String?
    let parentUUID: NSUUID?
    let keyPath: String?
    var properties: [String: AnyObject?]
    
    init(type: SyncFragmentType, objectUUID: NSUUID, clsName: String?, parentUUID: NSUUID?, keyPath: String?, properties: [String: AnyObject?]?) {
        self.type = type
        self.objectUUID = objectUUID
        self.clsName = clsName
        self.keyPath = keyPath
        self.parentUUID = parentUUID
        self.properties = properties != nil ? properties! : [String: AnyObject?]()
    }
    
    func serialize() -> [String: AnyObject] {
        let dictionary = [String: AnyObject]()
        return dictionary
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> SyncFragment? {
        var type: SyncFragmentType?
        var objectUUID: NSUUID?
        var clsName: String?
        var parentUUID: NSUUID?
        var keyPath: String?
        var properties: [String: AnyObject?]?

        for (key, value) in dictionary {
            switch key {
            case "type":
                if let valueAsString = value as? String {
                    if let definiteType = SyncFragmentType.fromRaw(valueAsString) {
                        type = definiteType
                    }
                }
            case "uuid":
                if let valueAsString = value as? String {
                    objectUUID = NSUUID(UUIDString: valueAsString)
                }
            case "properties":
                if let propertyDictionary = value as? Dictionary<String, AnyObject> {
                    properties = propertyDictionary
                }
            case "cls":
                if let valueAsString = value as? String {
                    clsName = valueAsString
                }
            case "keyPath":
                if let valueAsString = value as? String {
                    keyPath = valueAsString
                }
            case "parent":
                if let valueAsString = value as? String {
                    parentUUID = NSUUID(UUIDString: valueAsString)
                }
            default:
                // TODO: Log error
                println("unkown key \(key)")
            }
        }
        
        // Check validity of properties
        if type == nil || objectUUID == nil {
            return nil
        }
        if type == .Add && (clsName == nil || parentUUID == nil || keyPath == nil) {
            return nil
        }
        if type == .MoveChange && (parentUUID == nil || keyPath == nil) {
            return nil
        }

        return SyncFragment(type: type!, objectUUID: objectUUID!, clsName: clsName, parentUUID: parentUUID, keyPath: keyPath, properties: properties)
    }
    
    init(type:SyncFragmentType, modelObject: ModelObject) {
        self.type = type
        self.objectUUID = modelObject.uuid
        self.properties = Dictionary<String, AnyObject>()
        
        if (type == .Add) {
            self.clsName = NSStringFromClass(modelObject.dynamicType)
            self.keyPath = modelObject.parent?.keyPath
            applyPropertiesFromModelObject(modelObject)
        } else if (type == .MoveChange) {
            self.keyPath = modelObject.parent?.keyPath
        }
    }

    func applyPropertiesToModelObject(modelObject: ModelObject) {
        for (key, value) in properties {
            modelObject.setValue(value, forKey: key)
        }
    }
    
    func newValueForKey(key: String, value:AnyObject?) {
        properties[key] = value
    }
    
    func applyPropertiesFromModelObject(modelObject: ModelObject) {
        for (name, property) in modelObject.properties {
            if (!property.isArray) {
                let value: AnyObject? = modelObject.valueForKey(property.key)
                properties[name] = value
            }
        }
    }
    
    func applyChangesToScope(scope: Scope) {
        if (scope.modelObjects.count == 0) {
            return
        }
        
        switch type {
        case .Change:
            if let modelObject = scope.getObjectById(objectUUID) {
                applyPropertiesToModelObject(modelObject)
            }
        case .Add:
            if let definiteParentUUID = parentUUID {
                if let parentObject = scope.getObjectById(definiteParentUUID) {
                    
                    // TODO: Treading on freaking daggers here... Need to fix once swift allows string-to-class mapping
                    if (classPrefix == nil) {
                        var name = NSStringFromClass(scope.modelObjects.first!.dynamicType)
                        var split = name.componentsSeparatedByString(".")
                        split.removeLast()
                        classPrefix = ".".join(split)
                    }

                    if let modelObject = JTSObjectFactory.create("\(classPrefix!).\(clsName!)") as? ModelObject {
                        applyPropertiesToModelObject(modelObject)
                        if let definiteKeyPath = keyPath {
                            parentObject.setValue(modelObject, forKey: definiteKeyPath)
                        }
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