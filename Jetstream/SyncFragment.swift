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
}

private let OnlyTransmitNonDefaultValues = false
private var classPrefix: String?


public func ==(lhs: SyncFragment, rhs: SyncFragment) -> Bool {
    return lhs === rhs
}

public class SyncFragment: Equatable {
    let type: SyncFragmentType
    let objectUUID: NSUUID
    let clsName: String?
    var properties: [String: AnyObject]?
    
    init(type: SyncFragmentType, objectUUID: NSUUID, clsName: String?, properties: [String: AnyObject]?) {
        self.type = type
        self.objectUUID = objectUUID
        self.clsName = clsName
        self.properties = properties
    }
    
    func serialize() -> [String: AnyObject] {
        var dictionary = [String: AnyObject]()
        dictionary["type"] = type.toRaw()
        dictionary["uuid"] = objectUUID.UUIDString
        if clsName != nil {
            dictionary["cls"] = clsName!
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
        if (type == .Root || type == .Add) && clsName == nil {
            return nil
        }

        return SyncFragment(
            type: type!,
            objectUUID: objectUUID!,
            clsName: clsName,
            properties: properties)
    }
    
    init(type: SyncFragmentType, modelObject: ModelObject) {
        self.type = type
        self.objectUUID = modelObject.uuid

        if (type == .Add) {
            var fullyQualifiedClassName = NSStringFromClass(modelObject.dynamicType)
            var qualifiers = fullyQualifiedClassName.componentsSeparatedByString(".")
            self.clsName = qualifiers[qualifiers.count-1]
            applyPropertiesFromModelObject(modelObject)
        }
    }

    func applyPropertiesToModelObject(modelObject: ModelObject, scope: Scope, applyDefaults: Bool = false) {
        if var definiteProperties = properties {
            if (applyDefaults) {
                for (name, propertyInfo) in modelObject.properties {
                    if !contains(definiteProperties.keys, name) {
                        if (propertyInfo.defaultValue == nil) {
                            definiteProperties[name] = NSNull()
                        } else {
                            definiteProperties[name] = propertyInfo.defaultValue
                        }
                    }
                }
            }
            for (key, value) in definiteProperties {
                if let propertyInfo = modelObject.properties[key] {
                    switch propertyInfo.valueType {
                    case .ModelObject:
                        var applied = false
                        if let uuidString = value as? String {
                            let uuid = NSUUID(UUIDString: uuidString)
                            if let referencedModelObject = scope.getObjectById(uuid) {
                                modelObject.setValue(referencedModelObject, forKey: key)
                                applied = true
                            }
                        }
                        if !applied {
                            modelObject.setValue(nil, forKey: key)
                        }
                    case .Array:
                        var models = [ModelObject]()
                        if let uuids = value as? [String] {
                            for uuidString in uuids {
                                let uuid = NSUUID(UUIDString: uuidString)
                                if let referencedModelObject = scope.getObjectById(uuid) {
                                    models.append(referencedModelObject)
                                }
                            }
                        }
                        modelObject.setValue(models, forKey: key)
                    default:
                        modelObject.setValue(value, forKey: key)
                    }
                }
            }
        }
    }
    
    func newValueForKeyFromModelObject(key: String, value:AnyObject?, modelObject: ModelObject) {
        var appliedValue: AnyObject? = value
        if (value == nil) {
            appliedValue = NSNull()
        }
        let property = modelObject.properties[key]
        if (properties == nil) {
            properties = [String: AnyObject]()
        }
        properties![key] = value
    }
    
    func applyPropertiesFromModelObject(modelObject: ModelObject) {
        for (name, property) in modelObject.properties {
            if (property.valueType != .Array && property.valueType != .ModelObject) {
                if let value: AnyObject = modelObject.valueForKey(property.key) {
                    if (properties == nil) {
                        properties = [String: AnyObject]()
                    }
                    var apply: Bool = true
                    
                    if OnlyTransmitNonDefaultValues {
                        if let definiteDefaultValue: AnyObject = property.defaultValue {
                            let modelValue = convertAnyObjectToModelValue(value, property.valueType)
                            let defaultModelValue = convertAnyObjectToModelValue(definiteDefaultValue, property.valueType)
                            
                            if (modelValue != nil && defaultModelValue != nil) {
                                if modelValue!.equalTo(defaultModelValue!) {
                                    apply = false
                                }
                            }
                        }
                    }
                    if apply {
                        properties![name] = value
                    }
                }
            }
        }
    }
    
    func createObjectForScopeIfNecessary(scope: Scope) -> ModelObject? {
        if (type == .Add) {
            if let existingModelObject = scope.getObjectById(objectUUID) {
                return nil
            } else if clsName != nil {
                if let cls = ModelObject.Static.allTypes[clsName!] as? ModelObject.Type {
                    return cls(uuid: objectUUID)
                }
            }
        }
        return nil
    }
    
    func applyChangesToScope(scope: Scope, applyDefaults: Bool = false) {
        if (scope.rootModel == nil) {
            return
        }
        
        switch type {
        case .Root:
            if let definiteRootModel = scope.rootModel {
                applyPropertiesToModelObject(definiteRootModel, scope: scope, applyDefaults: applyDefaults)
                scope.updateUUIDForModel(definiteRootModel, uuid: self.objectUUID)
            }
        case .Change:
            if let modelObject = scope.getObjectById(objectUUID) {
                applyPropertiesToModelObject(modelObject, scope: scope, applyDefaults: applyDefaults)
            }
        case .Add:
            var modelObject: ModelObject?
            if let existingModelObject = scope.getObjectById(objectUUID) {
                modelObject = existingModelObject
            } else if clsName != nil {
                if let cls = ModelObject.Static.allTypes[clsName!] as? ModelObject.Type {
                    modelObject = cls(uuid: objectUUID)
                }
            }
            
            if let definiteModelObject = modelObject {
                applyPropertiesToModelObject(definiteModelObject, scope: scope, applyDefaults: applyDefaults)
            }
            
        case .Remove:
            if let modelObject = scope.getObjectById(objectUUID) {
                modelObject.detach()
            }
        }
    }
}
