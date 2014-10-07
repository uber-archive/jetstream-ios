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
    case Root = "root"
    case Change = "change"
    case Add = "add"
    case Remove = "remove"
    case MoveChange = "movechange"
}

private var classPrefix: String?

public func ==(lhs: SyncFragment, rhs: SyncFragment) -> Bool {
    return lhs === rhs
}

public class SyncFragment: Equatable {

    let type: SyncFragmentType
    let objectUUID: NSUUID
    let clsName: String?
    let keyPath: String?
    let parentUUID: NSUUID?
    var properties: [String: AnyObject]?
    
    init(type: SyncFragmentType, objectUUID: NSUUID, clsName: String?, keyPath: String?, parentUUID: NSUUID?, properties: [String: AnyObject]?) {
        self.type = type
        self.objectUUID = objectUUID
        self.clsName = clsName
        self.keyPath = keyPath
        self.parentUUID = parentUUID
        self.properties = properties
    }
    
    func serialize() -> [String: AnyObject] {
        var dictionary = [String: AnyObject]()
        dictionary["type"] = type.toRaw()
        dictionary["uuid"] = objectUUID.UUIDString
        if clsName != nil {
            dictionary["cls"] = clsName!
        }
        if keyPath != nil {
            dictionary["keyPath"] = keyPath!
        }
        if parentUUID != nil {
            dictionary["parent"] = parentUUID?.UUIDString
        }
        if properties != nil {
            dictionary["properties"] = properties!
        }
        return dictionary
    }
    
    class func unserialize(dictionary: [String: AnyObject]) -> SyncFragment? {
        var type: SyncFragmentType?
        var objectUUID: NSUUID?
        var clsName: String?
        var parentUUID: NSUUID?
        var keyPath: String?
        var properties: [String: AnyObject]?

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
            case "properties":
                if let propertyDictionary = value as? Dictionary<String, AnyObject> {
                    properties = propertyDictionary
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
        if type == .Root && clsName == nil {
            return nil
        }
        if type == .Add && (clsName == nil || parentUUID == nil || keyPath == nil) {
            return nil
        }
        if type == .MoveChange && (parentUUID == nil || keyPath == nil) {
            return nil
        }

        return SyncFragment(
            type: type!,
            objectUUID: objectUUID!,
            clsName: clsName,
            keyPath: keyPath,
            parentUUID: parentUUID,
            properties: properties)
    }
    
    init(type: SyncFragmentType, modelObject: ModelObject) {
        self.type = type
        self.objectUUID = modelObject.uuid

        if (type == .Add) {
            var fullyQualifiedClassName = NSStringFromClass(modelObject.dynamicType)
            var qualifiers = fullyQualifiedClassName.componentsSeparatedByString(".")
            self.clsName = qualifiers[qualifiers.count-1]
            self.parentUUID = modelObject.parent?.parent.uuid
            self.keyPath = modelObject.parent?.keyPath
            applyPropertiesFromModelObject(modelObject)
        } else if (type == .MoveChange) {
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
    
    
    func newValueForKeyFromModelObject(key: String, value:AnyObject?, modelObject: ModelObject) {
        let property = modelObject.properties[key]
        if property == nil || property!.isCollection || property!.isModelObject {
            return
        }
        
        if (properties == nil) {
            properties = [String: AnyObject]()
        }
        properties![key] = value
    }
    
    func applyPropertiesFromModelObject(modelObject: ModelObject) {
        for (name, property) in modelObject.properties {
            if (!property.isCollection && !property.isModelObject) {
                if let value: AnyObject = modelObject.valueForKey(property.key) {
                    if (properties == nil) {
                        properties = [String: AnyObject]()
                    }
                    properties![name] = value
                }
            }
        }
    }
    
    func applyChangesToScope(scope: Scope) {
        if (scope.rootModel == nil) {
            return
        }
        
        switch type {
        case .Root:
            if let definiteRootModel = scope.rootModel {
                applyPropertiesToModelObject(definiteRootModel)
                scope.updateUUIDForModel(definiteRootModel, uuid: self.objectUUID)
            }
        case .Change:
            if let modelObject = scope.getObjectById(objectUUID) {
                applyPropertiesToModelObject(modelObject)
            }
        case .Add:
            if let definiteParentUUID = parentUUID {
                if let parentObject = scope.getObjectById(definiteParentUUID) {
                    if clsName != nil {
                        if let cls = ModelObject.Static.allTypes[clsName!] as? ModelObject.Type {
                            let modelObject: ModelObject = cls(uuid: objectUUID)
                            applyPropertiesToModelObject(modelObject)
                            if let definiteKeyPath = keyPath {
                                if let propertyInfo: PropertyInfo = parentObject.properties[definiteKeyPath] {
                                    if propertyInfo.isModelObject && !propertyInfo.isCollection {
                                        parentObject.setValue(modelObject, forKey: definiteKeyPath)
                                    } else if propertyInfo.isModelObject && propertyInfo.isCollection {
                                        if var array = parentObject.valueForKey(definiteKeyPath) as? [AnyObject] {
                                            let length = array.count
                                            array.append(modelObject)
                                            let indexes = NSIndexSet(index: length)
                                            parentObject.willChange(.Insertion, valuesAtIndexes: indexes, forKey: definiteKeyPath)
                                            parentObject.setValue(array, forKey: definiteKeyPath)
                                            parentObject.didChange(.Insertion, valuesAtIndexes: indexes, forKey: definiteKeyPath)
                                        }
                                    }
                                }
                            }
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
