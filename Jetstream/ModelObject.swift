//
//  ModelObject.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public struct ParentRelationship: Equatable {
    var parent: ModelObject
    var keyPath: String
}

public func ==(lhs: ParentRelationship, rhs: ParentRelationship) -> Bool {
    return lhs.parent == rhs.parent && lhs.keyPath == rhs.keyPath
}

private var myContext = 0

struct PropertyInfo {
    let key: String
    let isArray: Bool
}

@objc public class ModelObject: NSObject {
    
    public let onPropertyChange = Signal<(keyPath: String, value: AnyObject?)>()
    public let onModelAddedToCollection = Signal<(keyPath: String, element: AnyObject, atIndex:Int)>()
    public let onModelRemovedFromCollection = Signal<(keyPath: String, element: AnyObject, atIndex:Int)>()
    public let onDetachedFromScope = Signal<(Scope)>()
    public let onAttachToScope = Signal<(scope: Scope, parent: ModelObject, keyPath: String)>()
    public let onMovedBetweenScopes = Signal<(parent: ModelObject, keyPath: String)>()
    
    public let uuid: NSUUID;
    var properties = Dictionary<String, PropertyInfo>()
    
    private var internalIsScopeRoot = false;
    public var isScopeRoot: Bool {
        get {
            return internalIsScopeRoot
        }
        set {
            if (isScopeRoot != newValue) {
                internalIsScopeRoot = newValue
                if (newValue == false && scope != nil) {
                    scope!.removeModelObject(self)
                    onDetachedFromScope.fire(scope!)
                }
                if (newValue) {
                    setScopeAndMakeRootModel(Scope(name: object_getClass(self).description()))
                } else {
                    scope = nil
                }
            }
        }
    }
    
    var _scope: Scope?
    var scope: Scope? {
        get {
            return _scope
        }
        
        set(value) {
            if (_scope !== value) {
                let oldScope = _scope
                _scope = value
                
                if (oldScope != nil) {
                    oldScope!.removeModelObject(self)
                }
                
                if let definiteParent = parent {
                    if let definiteOldScope = oldScope {
                        onDetachedFromScope.fire(definiteOldScope)
                    }
                    if let definiteScope = scope {
                        definiteScope.addModelObject(self)
                        onAttachToScope.fire(scope: definiteScope, parent: definiteParent.parent, keyPath: definiteParent.keyPath)
                    }
                }
                
                for child in childModelObjects {
                    if (child != self) {
                        child.scope = scope
                    }
                }
            }
        }
    }

    public var parent: ParentRelationship? {
        willSet(newValue) {
            if parent != newValue {
                if let definiteParent = parent {
                    definiteParent.parent.onPropertyChange.removeListener(self)
                }
                if newValue == nil && !isScopeRoot {
                    scope = nil
                }
            }
        }
        
        didSet(oldValue) {
            if parent != oldValue {
                if let newParent = parent {
                    newParent.parent.onPropertyChange.listen(self, callback: { (keyPath, value) -> Void in
                        if (keyPath == newParent.keyPath) {
                            if (value as? ModelObject) != self {
                                self.parent = nil
                            }
                        }
                    })
                    if oldValue != nil && oldValue!.parent.scope != nil {
                        onMovedBetweenScopes.fire(parent: newParent.parent, keyPath: newParent.keyPath)
                    }
                }
                if let definiteOldParent = oldValue {
                    if definiteOldParent.parent.valueForKey(definiteOldParent.keyPath) === self {
                        definiteOldParent.parent.setValue(nil, forKey: definiteOldParent.keyPath)
                    }
                }
                if let definiteParent = parent {
                    scope = definiteParent.parent.scope
                }
            }
        }
    }
    
    private var childModelObjects: [ModelObject] {
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
    
    private func setupPropertyListeners() {
        let mirror = reflect(self)
        for i in 0...mirror.count - 1 {
            var (name, type) = mirror[i]
            if name != "super" {
                var isArray = false
                if let asArray = self.valueForKey(name) as? [ModelObject] {
                    isArray = true
                }
                
                properties[name] = PropertyInfo(key: name, isArray:isArray)
                self.addObserver(self, forKeyPath: name, options: .New | .Old, context: &myContext)
            }
        }
    }
    
    private func keyPathChanged(keyPath: String, oldValue: AnyObject?, newValue: AnyObject?) {
        let newArray = newValue as? [ModelObject]
        let oldArray = oldValue as? [ModelObject]
        
        if newArray != nil && oldArray != nil {
            var index: Int = 0
        
            // TODO: Optimize this
            for index in 0 ..< oldArray!.count {
                if !contains(newArray!, oldArray![index]) {
                    let model = oldArray![index]
                    model.parent = nil
                    onModelRemovedFromCollection.fire(keyPath: keyPath, element: model as AnyObject, atIndex: index)
                }
            }
            for index in 0 ..< newArray!.count {
                if !contains(oldArray!, newArray![index]) {
                    let model = newArray![index]
                    model.parent = ParentRelationship(parent: self, keyPath: keyPath)
                    model.scope = scope
                    onModelAddedToCollection.fire(keyPath: keyPath, element: model as AnyObject, atIndex: index)
                }
            }
        } else {
            onPropertyChange.fire(keyPath: keyPath, value: newValue)
            if let modelObject = newValue as? ModelObject {
                modelObject.parent = ParentRelationship(parent: self, keyPath: keyPath)
                modelObject.scope = scope
            }
        }
    }

    override public func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if context == &myContext {
            keyPathChanged(keyPath, oldValue: change[NSKeyValueChangeOldKey], newValue: change[NSKeyValueChangeNewKey])
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    /// Assigns a scope to the model object and makes it the new root for the scope.
    ///
    /// :param: The scope to add the model object to.
    public func setScopeAndMakeRootModel(scope: Scope) {
        internalIsScopeRoot = true
        self.scope = scope
        scope.addModelObject(self)
        parent = nil
    }
    
    // MARK: - Public API

    /// Fires a listener whenever a specific property changes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPath The keyPath of the property to listen to.
    /// :param: callback The closure that gets executed every time the property changes.
    public func observeChange(listener: AnyObject, keyPath: String, callback: () -> Void) {
        let listener = onPropertyChange.listen(listener) { (keyPath, value) -> Void in
            callback()
        }
        listener.setFilter { (changedKeyPath, value) -> Bool in
            return keyPath == changedKeyPath
        }
    }
    
    /// Fires a listener whenever any of the specific properties change.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: keyPaths An array of keyPaths to listen to
    /// :param: callback The closure that gets executed every time any of the  properties change.
    public func observeChange(listener: AnyObject, keyPaths: [String], callback: () -> Void) {
        let listener = onPropertyChange.listen(listener) { (keyPath, value) -> Void in
            callback()
        }
        listener.setFilter { (changedKeyPath, value) -> Bool in
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
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope.
    public func observeAttach(listener: AnyObject, callback: () -> Void) {
        let listener = onAttachToScope.listen(listener)  { (scopeRoot, parent, keyPath) -> Void in
            callback()
        }
    }
    
    /// Fires a listener whenever the ModelObject is attached to a scope.
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope.
    public func observeDetach(listener: AnyObject, callback: () -> Void) {
        let listener = onDetachedFromScope.listen(listener)  { (scopeRoot) -> Void in
            callback()
        }
    }
    
    /// Fires a listener whenever the ModelObject is moved between scopes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is moved between scopes.
    public func observeMove(listener: AnyObject, callback: () -> Void) {
        let listener = onMovedBetweenScopes.listen(listener)  { (scopeRoot) -> Void in
            callback()
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
        onMovedBetweenScopes.removeListener(listener)
    }
    
    /// Removes the ModelObject from its scope.
    public func detach() {
        parent = nil
    }
}
