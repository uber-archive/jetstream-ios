//
//  SyncFragment.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

/// Fragment types
public enum SyncFragmentType: String {
    /// Denotes a fragment that changes the properties of an object in the scope.
    case Change = "change"
    
    /// Denotes a fragment that adds a new ModelObject to the scope.
    case Add = "add"
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
        self.objectUUID = modelObject.UUID
        
        if type == .Add {
            self.clsName = modelObject.className
            applyPropertiesFromModelObject(modelObject)
        }
    }
    
    /// Serializes the sync fragment into an JSON-serializable dictionary.
    ///
    /// :returns: A JSON-serializable dictionary representing the sync fragment.
    public func serialize() -> [String: AnyObject] {
        var dictionary = [String: AnyObject]()
        dictionary["type"] = type.rawValue
        dictionary["UUID"] = objectUUID.UUIDString
        if clsName != nil {
            dictionary["clsName"] = clsName!
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
            case "UUID":
                if let valueAsString = value as? String {
                    objectUUID = NSUUID(UUIDString: valueAsString)
                }
            case "clsName":
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
        if type == .Add && clsName == nil {
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
            if applyDefaults {
                for (name, property) in modelObject.properties {
                    if property.valueType == ModelValueType.Composite {
                        continue
                    }
                    if !contains(definiteProperties.keys, name) {
                        if property.defaultValue == nil {
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
                        if propertyInfo.acceptsNil {
                            modelObject.setValue(nil, forKey: key)
                        }
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
            if property.valueType == .Composite {
                continue
            }
            if let value: AnyObject = modelObject.valueForKey(property.key) {
                if let modelValue = convertAnyObjectToModelValue(value, property.valueType) {
                    if properties == nil {
                        properties = [String: AnyObject]()
                    }
                    var apply: Bool = true
                    
                    if OnlyTransmitNonDefaultValues {
                        if let definiteDefaultValue: AnyObject = property.defaultValue {
                            let modelValue = convertAnyObjectToModelValue(value, property.valueType)
                            let defaultModelValue = convertAnyObjectToModelValue(definiteDefaultValue, property.valueType)
                            
                            if modelValue != nil && defaultModelValue != nil {
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
        if type == .Add {
            if let existingModelObject = scope.getObjectById(objectUUID) {
                return existingModelObject
            } else if clsName != nil {
                if let cls = ModelObject.Static.allTypes[clsName!] as? ModelObject.Type {
                    return cls(UUID: objectUUID)
                }
            }
        }
        return nil
    }
    
    func applyChangesToScope(scope: Scope, applyDefaults: Bool = false) {
        if scope.root == nil {
            return
        }
        
        switch type {
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
                    modelObject = cls(UUID: objectUUID)
                }
            }
            
            if let definiteModelObject = modelObject {
                applyPropertiesToModelObject(definiteModelObject, scope: scope, applyDefaults: applyDefaults)
            }
        }
    }
}

public func ==(lhs: SyncFragment, rhs: SyncFragment) -> Bool {
    return lhs === rhs
}
