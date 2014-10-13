//
//  ModelObject.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

public struct ParentRelationship: Equatable {
    var parent: ModelObject
    var keyPath: String
    var listener: SignalListener<(key: String, oldValue: AnyObject?, value: AnyObject?)>?
    
    init(parent: ModelObject, keyPath: String) {
        self.parent = parent
        self.keyPath = keyPath
    }
}

public func ==(lhs: ParentRelationship, rhs: ParentRelationship) -> Bool {
    return lhs.parent == rhs.parent && lhs.keyPath == rhs.keyPath
}

private var voidContext = 0

struct PropertyInfo {
    let key: String
    let valueType: ModelValueType
    let defaultValue: AnyObject?
}

@objc public class ModelObject: NSObject {
    public let onPropertyChange = Signal<(key: String, oldValue: AnyObject?, value: AnyObject?)>()
    public let onModelAddedToCollection = Signal<(key: String, element: AnyObject, atIndex:Int)>()
    public let onModelRemovedFromCollection = Signal<(key: String, element: AnyObject, atIndex:Int)>()
    public let onDetachedFromScope = Signal<(Scope)>()
    public let onAttachToScope = Signal<(Scope)>()
    public let onAddedParent = Signal<(parent: ModelObject, key: String)>()
    public let onRemovedParent = Signal<(parent: ModelObject, key: String)>()
    
    struct Static {
        static var allTypes = [String: AnyClass]()
        static var compositeDependencies = [String: [String: [String]]]()
    }

    override public class func initialize() {
        let name = NSStringFromClass(self)
        
        // Warning: Just assuming that Swift will forever have a prefix followed by a dot and the classname
        let components = name.componentsSeparatedByString(".")
        let lastComponent = components[components.count-1]
        Static.allTypes[lastComponent] = self
        
        var keyToDependencies = [String: [String]]()
        for (prop, dependencies) in getCompositeDependencies() {
            for dependency in dependencies {
                if var definiteDependecy = keyToDependencies[dependency] {
                    definiteDependecy.append(prop)
                } else {
                    keyToDependencies[dependency] = [prop]
                }
            }
        }
        Static.compositeDependencies[name] = keyToDependencies
    }
    
    public class func getCompositeDependencies() -> [String: [String]] {
        return [String :[String]]()
    }
    
    public internal(set) var uuid: NSUUID
    var properties = Dictionary<String, PropertyInfo>()
    
    private var internalIsScopeRoot = false
    public var isScopeRoot: Bool {
        get {
            return internalIsScopeRoot
        }
        set {
            if (isScopeRoot != newValue) {
                internalIsScopeRoot = newValue
                if (newValue) {
                    setScopeAndMakeRootModel(Scope(name: object_getClass(self).description()))
                } else {
                    scope = nil
                }
            }
        }
    }
    
    private var internalScope: Scope?
    var scope: Scope? {
        get {
            return internalScope
        }
        set(value) {
            if (internalScope !== value) {
                let oldScope = internalScope
                internalScope = value
                
                if (oldScope != nil) {
                    oldScope!.removeModelObject(self)
                }
                
                if let definiteOldScope = oldScope {
                    onDetachedFromScope.fire(definiteOldScope)
                }
                if let definiteScope = scope {
                    definiteScope.addModelObject(self)
                    onAttachToScope.fire(definiteScope)
                }

                for child in childModelObjects {
                    if (child != self) {
                        child.scope = scope
                    }
                }
            }
        }
    }

    var parents = [ParentRelationship]()
    
    var childModelObjects: [ModelObject] {
        get {
            var objects = Array<ModelObject>()
            for property in properties.values {
                if let modelObject = self.valueForKey(property.key) as? ModelObject {
                    objects.append(modelObject)
                }
            }
            return objects
        }
    }
    
    var propertyValuePairs: [String: AnyObject]? {
        get {
            var propertyValues = [String: AnyObject]()
            for (key, value) in properties {
                if let propertyValue: AnyObject = valueForKey(key) as AnyObject? {
                    propertyValues[key] = propertyValue
                }
                
            }
            if propertyValues.count > 0 {
                return propertyValues
            } else {
                return nil
            }
        }
    }

    public override init() {
        uuid = NSUUID()
        super.init()
        setupPropertyListeners()
    }
    
    required public init(uuid: NSUUID) {
        self.uuid = uuid
        super.init()
        setupPropertyListeners()
    }
    
    convenience init(uuidString: String) {
        self.init(uuid: NSUUID(UUIDString: uuidString))
    }
    
    deinit {
        for property in properties.values {
            removeObserver(self, forKeyPath: property.key)
        }
    }

    func setupPropertyListeners() {
        // TODO: Do this only once and store as static
        var propertyCount: UInt32 = 0
        let propertyList = class_copyPropertyList(self.dynamicType, &propertyCount)
        
        for i in 0..<Int(propertyCount) {
            var propertyCName = property_getName(propertyList[i])
            if propertyCName != nil {
                let propertyName = NSString.stringWithCString(propertyCName, encoding: NSString.defaultCStringEncoding()) as String
                let propertyAttributes = property_getAttributes(propertyList[i])
                let attributes = NSString.stringWithCString(propertyAttributes, encoding: NSString.defaultCStringEncoding())
                let components = attributes.componentsSeparatedByString(",")
   
                if components.count > 2 {
                    var type: NSString = (components[0] as NSString).substringFromIndex(1)
                    var accessible = (components[2] as String) != "R"

                    var valueType: ModelValueType?
                    if let asArray = self.valueForKey(propertyName) as? [ModelObject] {
                        valueType = .Array
                    } else if type.containsString("@\"") {
                        // Assuming that every custom type extends from ModelObject
                        valueType = .ModelObject
                    } else if let definiteValueType = ModelValueType.fromRaw(type) {
                        valueType = definiteValueType
                    }
                    
                    if let definiteValueType = valueType {
                        if accessible {
                            self.addObserver(self, forKeyPath: propertyName, options: .New | .Old, context: &voidContext)
                            let defaultValue: AnyObject? = valueForKey(propertyName)
                            properties[propertyName] = PropertyInfo(key: propertyName, valueType: definiteValueType, defaultValue: defaultValue)
                        }
                    }
                    
                }
            }
        }
        free(propertyList)
    }
    
    func dependenciesForKey(key: String) -> [String]? {
        if let definiteKeyToDependencies = Static.compositeDependencies[NSStringFromClass(self.dynamicType)] {
            return definiteKeyToDependencies[key]
        }
        return nil
    }
    
    func addParentRelationship(parentRelationship: ParentRelationship) {
        if find(parents, parentRelationship) == nil {
            assert(scope == nil || scope === parentRelationship.parent.scope, "Attaching a model object to two scopes is currently not supported")
            
            var relationship = parentRelationship
           
            relationship.listener = relationship.parent.onPropertyChange.listen(self) { [weak self] (key, oldValue, value) -> Void in
                if let strongSelf = self {
                    if (key == relationship.keyPath) {
                        if let definitePropertyInfo = strongSelf.properties[key] {
                            if definitePropertyInfo.valueType == ModelValueType.ModelObject {
                                if value !== strongSelf {
                                    strongSelf.removeParentRelationship(relationship)
                                }
                            } else if definitePropertyInfo.valueType == ModelValueType.Array {
                                if let arrayContents = value as? [ModelObject] {
                                    if !contains(arrayContents, strongSelf) {
                                        strongSelf.removeParentRelationship(relationship)
                                    }
                                }

                            }
                        }
                    }
                }
            }
            parents.append(relationship)
            
            onAddedParent.fire((parent: parentRelationship.parent, key: parentRelationship.keyPath))

            if (parents.count == 1) {
                scope = parentRelationship.parent.scope
            }
        }
    }    
    
    func removeParentRelationship(parentRelationship: ParentRelationship) {
        if let index = find(parents, parentRelationship) {
            parents.removeAtIndex(index)
            if let definiteListener = parentRelationship.listener {
                definiteListener.cancel()
            }
            parentRelationship.parent.removeChildAtKeyPath(parentRelationship.keyPath, child: self)
            if (parents.count == 0) {
                scope = nil
            }
        }
    }

    func removeChildAtKeyPath(key: String, child: ModelObject) {
        if let definitePropertyInfo = properties[key] {
            if (definitePropertyInfo.valueType == ModelValueType.Array) {
                if var array = valueForKey(key) as? [ModelObject] {
                    if let index = find(array, child) {
                        array.removeAtIndex(index)
                        self.setValue(array, forKey: key)
                    }
                }
            } else {
                if valueForKey(key) === child {
                    self.setValue(nil, forKey: key)
                }
            }
        }
    }
    
    func keyPathChanged(keyPath: String, oldValue: AnyObject?, newValue: AnyObject?) {
        let newArray = newValue as? [ModelObject]
        let oldArray = oldValue as? [ModelObject]
        
        if newArray != nil && oldArray != nil {
            var index: Int = 0
        
            // TODO: Optimize this
            for index in 0 ..< oldArray!.count {
                if !contains(newArray!, oldArray![index]) {
                    let model = oldArray![index]
                    model.removeParentRelationship(ParentRelationship(parent: self, keyPath: keyPath))
                    onModelRemovedFromCollection.fire(key: keyPath, element: model as AnyObject, atIndex: index)
                }
            }
            for index in 0 ..< newArray!.count {
                if !contains(oldArray!, newArray![index]) {
                    let model = newArray![index]
                    model.addParentRelationship(ParentRelationship(parent: self, keyPath: keyPath))
                    onModelAddedToCollection.fire(key: keyPath, element: model as AnyObject, atIndex: index)
                }
            }
        } else if let modelObject = newValue as? ModelObject {
            modelObject.addParentRelationship(ParentRelationship(parent: self, keyPath: keyPath))
        }
        
        onPropertyChange.fire(key: keyPath, oldValue: oldValue, value: newValue)
        
        if let dependencies = dependenciesForKey(keyPath) {
            for dependency in dependencies {
                onPropertyChange.fire(key: dependency, oldValue: nil, value: nil)
            }
        }
    }

    override public func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if context == &voidContext {
            var oldValue: AnyObject? = change[NSKeyValueChangeOldKey]
            var newValue: AnyObject? = change[NSKeyValueChangeNewKey]
            var notify: Bool = true
            if oldValue == nil && newValue == nil {
                notify = false
            } else if oldValue != nil && newValue != nil {
                var valueType = properties[keyPath]!.valueType
                var oldModelValue = convertAnyObjectToModelValue(oldValue!, valueType)
                var newModelValue = convertAnyObjectToModelValue(newValue!, valueType)
                if (oldModelValue == nil && newModelValue == nil) {
                    notify = false
                } else if (oldModelValue != nil && newModelValue != nil) {
                    if oldModelValue!.equalTo(newModelValue!) {
                        notify = false
                    }
                }
            }
            if (notify) {
                keyPathChanged(keyPath, oldValue: oldValue, newValue: newValue)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: - Public API
    
    /// Assigns a scope to the model object and makes it the new root for the scope.
    ///
    /// :param: The scope to add the model object to.
    public func setScopeAndMakeRootModel(scope: Scope) {
        detach()
        internalIsScopeRoot = true
        self.scope = scope
    }

    /// Fires a listener whenever any property or collection on the object changes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the object changes.
    public func observeChange(listener: AnyObject, callback: () -> Void) {
        let listener = onPropertyChange.listen(listener) { (keyPath, oldValue, value) -> Void in
            callback()
        }
    }
    
    /// Fires a listener whenever a specific property changes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPath The keyPath of the property to listen to.
    /// :param: callback The closure that gets executed every time the property changes.
    public func observeChange(listener: AnyObject, keyPath: String, callback: () -> Void) {
        let listener = onPropertyChange.listen(listener) { (keyPath, oldValue, value) -> Void in
            callback()
        }
        listener.setFilter { (changedKeyPath, oldValue, value) -> Bool in
            return keyPath == changedKeyPath
        }
    }
    
    /// Fires a listener whenever any of the specific properties change.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPaths An array of keyPaths to listen to.
    /// :param: callback The closure that gets executed every time any of the  properties change.
    public func observeChange(listener: AnyObject, keyPaths: [String], callback: () -> Void) {
        let listener = onPropertyChange.listen(listener) { (keyPath, oldValue, value) -> Void in
            callback()
        }
        listener.setFilter { (changedKeyPath, oldValue, value) -> Bool in
            return keyPaths.reduce(false, combine: { return $0 || $1 == changedKeyPath })
        }
    }
    
    /// Fires a listener whenever a specific collection adds an element.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPath The keyPath of the the collection to listen to.
    /// :param: callback The closure that gets executed every time the collection adds an element. Set the type of the element
    /// in the callback to the appropriate type of the collection.
    public func observeCollectionAdd<T>(listener: AnyObject, keyPath: String, callback: (element: T) -> Void) {
        let listener = onModelAddedToCollection.listen(listener) { (keyPath, element, atIndex) -> Void in
            if let definiteElement = element as? T {
                callback(element: element as T)
            }
        }
        listener.setFilter { (changedKeyPath, element, atIndex) -> Bool in
            return keyPath == changedKeyPath
        }
    }
    
    /// Fires a listener whenever a specific collection removes an element.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPath The keyPath of the the collection to listen to.
    /// :param: callback The closure that gets executed every time the collection removes an element. Set the type of the element
    /// in the callback to the appropriate type of the collection.
    public func observeCollectionRemove<T>(listener: AnyObject, keyPath: String, callback: (element: T) -> Void) {
        let listener = onModelRemovedFromCollection.listen(listener) { (keyPath, element, atIndex) -> Void in
            if let definiteElement = element as? T {
                callback(element: element as T)
            }
        }
        listener.setFilter { (changedKeyPath, element, atIndex) -> Bool in
            return keyPath == changedKeyPath
        }
    }
    
    /// Fires a listener whenever the ModelObject is attached to a scope.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope. The scope argument
    /// contains the scope to which the model object was attached to.
    public func observeAttach(listener: AnyObject, callback: (scope: Scope) -> Void) {
        let listener = onAttachToScope.listen(listener)  { (scope) -> Void in
            callback(scope: scope)
        }
    }
    
    /// Fires a listener whenever the ModelObject is attached to a scope.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope. The scope argument
    /// contains the scope from which the model object was removed from.
    public func observeDetach(listener: AnyObject, callback: (scope: Scope) -> Void) {
        let listener = onDetachedFromScope.listen(listener)  { (scope) -> Void in
            callback(scope: scope)
        }
    }
    
    /// Fires a listener whenever the ModelObject is moved between scopes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is moved between scopes. The scope argument
    /// contains the new scope of the model object.
    public func observeAddedToParent(listener: AnyObject, callback: (parent: ModelObject, key: String) -> Void) {
        let listener = onAddedParent.listen(listener) { (parent, key) -> Void in
            callback(parent: parent, key:key)
        }
    }
    
    /// Fires a listener whenever the ModelObject is moved between scopes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is moved between scopes.
    public func observeRemovedFromParent(listener: AnyObject, callback: (parent: ModelObject, key: String) -> Void) {
        let listener = onRemovedParent.listen(listener) { (parent, key) -> Void in
            callback(parent: parent, key: key)
        }
    }
    
    /// Removes all observers and signal listeners for a listening object.
    ///
    /// :param: listener The listener to remove.
    public func removeObservers(listener: AnyObject) {
        onModelAddedToCollection.removeListener(listener)
        onModelRemovedFromCollection.removeListener(listener)
        onDetachedFromScope.removeListener(listener)
        onAttachToScope.removeListener(listener)
        onAddedParent.removeListener(listener)
        onRemovedParent.removeListener(listener)
    }
    
    /// Removes the ModelObject from its scope.
    public func detach() {
        for parentRelationship in parents {
            removeParentRelationship(parentRelationship)
        }
    }
}
