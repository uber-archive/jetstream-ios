//
//  SyncFragment.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Jetstream

/// Fragment types
public enum SyncFragmentType: String {
    /// Denotes a fragment that changes the properties of a root object of the scope.
    case Root = "root"
    
    /// Denotes a fragment that changes the properties of an object in the scope.
    case Change = "change"
    
    /// Denotes a fragment that adds a new ModelObject to the scope.
    case Add = "add"
    
    /// Denotes a fragment that removes an object from the scope.
    case Remove = "remove"
}

private let OnlyTransmitNonDefaultValues = false
private var classPrefix: String?

public class SyncFragment: Equatable {
    /// The type of the fragment.
    public let type: SyncFragmentType
    
    /// The UUID of the object that the fragment is associated with.
    public let objectUUID: NSUUID
    
    /// The name of the class to create in the case of an Add fragment.
    public let clsName: String?
    
    /// A dictionary of key-value pairs to apply to the object associated with the fragment.
    public var properties: [String: AnyObject]?
    
    var originalProperties: [String: AnyObject]?
    
    /// Creates a new fragment.
    ///
    /// :param: type The type of the fragment
    /// :param: objectUUID The UUID of the associated object.
    /// :clsName: The name of the class to instantiate in case of an Add fragment.
    /// :properties: A dictionary of key-value pairs of properties to apply to the associated model object
    /// in case the fragment is not of type Remove.
    init(type: SyncFragmentType, objectUUID: NSUUID, clsName: String?, properties: [String: AnyObject]?) {
        self.type = type
        self.objectUUID = objectUUID
        self.clsName = clsName
        self.properties = properties
    }
    
    /// Creates a new fragment.
    ///
    /// :param: type The type of the fragment
    /// :param: modelObject The model object to associate the fragment with. Properties will be copied over
    /// from the model object.
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
    
    /// Serializes the sync fragment into an JSON-serializable dictionary.
    ///
    /// :returns: A JSON-serializable dictionary representing the sync fragment.
    public func serialize() -> [String: AnyObject] {
        var dictionary = [String: AnyObject]()
        dictionary["type"] = type.rawValue
        dictionary["uuid"] = objectUUID.UUIDString
        if clsName != nil {
            dictionary["cls"] = clsName!
        }
        if properties != nil {
            dictionary["properties"] = properties!
        }
        return dictionary
    }
    
    /// Creates a sync fragment from a dictionary.
    ///
    /// :param: dictionary The dictionary to unserialize the sync fragment from.
    /// :returns: A sync fragment if unserialization was successfull.
    public class func unserialize(dictionary: [String: AnyObject]) -> SyncFragment? {
        var type: SyncFragmentType?
        var objectUUID: NSUUID?
        var clsName: String?
        var properties: [String: AnyObject]?
        
        let logger = Logging.loggerFor("Transport")

        for (key, value) in dictionary {
            switch key {
            case "type":
                if let valueAsString = value as? String {
                    if let definiteType = SyncFragmentType(rawValue: valueAsString) {
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
                logger.warn("Dictionary provided for unserialization of sync fragment contained unkown key \(key)")
            }
        }
        
        // Check validity of properties
        if type == nil || objectUUID == nil {
            logger.error("Could not unserialize SyncFragment. Type and objectUUID are required")
            return nil
        }
        if (type == .Root || type == .Add) && clsName == nil {
            logger.error("Could not unserialize SyncFragment. clsName is required for fragments of type Root and Add")
            return nil
        }

        return SyncFragment(
            type: type!,
            objectUUID: objectUUID!,
            clsName: clsName,
            properties: properties)
    }

    func applyPropertiesToModelObject(modelObject: ModelObject, scope: Scope, applyDefaults: Bool = false) {
        if var definiteProperties = properties {
            if (applyDefaults) {
                for (name, property) in modelObject.properties {
                    if (property.valueType == ModelValueType.Composite) {
                        continue
                    }
                    if !contains(definiteProperties.keys, name) {
                        if (property.defaultValue == nil) {
                            definiteProperties[name] = NSNull()
                        } else {
                            definiteProperties[name] = property.defaultValue
                        }
                    }
                }
            }
            for (key, value) in definiteProperties {
                if let propertyInfo = modelObject.properties[key] {
                    if let convertedValue: AnyObject = unserializeModelValue(value, scope, propertyInfo.valueType) {
                        modelObject.setValue(convertedValue, forKey: key)
                    } else {
                        modelObject.setValue(nil, forKey: key)
                    }
                }
            }
        }
    }
    
    func newValueForKeyFromModelObject(key: String, newValue:ModelValue?, oldValue: AnyObject?, modelObject: ModelObject) {
        if properties == nil {
            properties = [String: AnyObject]()
        }
        if originalProperties == nil {
            originalProperties = [String: AnyObject]()
        }
        if originalProperties![key] == nil {
            if oldValue == nil {
                originalProperties![key] = NSNull()
            } else {
                originalProperties![key] = oldValue
            }
        }
        if newValue == nil {
            properties![key] = NSNull()
        } else {
            properties![key] = newValue!.serialize()
        }
    }
    
    func applyPropertiesFromModelObject(modelObject: ModelObject) {
        for (name, property) in modelObject.properties {
            if (property.valueType == .Composite) {
                continue
            }
            if let value: AnyObject = modelObject.valueForKey(property.key) {
                if let modelValue = convertAnyObjectToModelValue(value, property.valueType) {
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
                        properties![name] = modelValue.serialize()
                    }
                }
            }
        }
    }
    
    func createObjectForScopeIfNecessary(scope: Scope) -> ModelObject? {
        if (type == .Add) {
            if let existingModelObject = scope.getObjectById(objectUUID) {
                return existingModelObject
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

public func ==(lhs: SyncFragment, rhs: SyncFragment) -> Bool {
    return lhs === rhs
}
