//
//  ModelObject.swift
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
import Signals

/// A function that when invoked canceles the associated observer.
public typealias CancelObserver = (() -> (Void))!

public struct ParentRelationship: Equatable {
    var parent: ModelObject
    var key: String
    var listener: SignalListener<(key: String, oldValue: AnyObject?, value: AnyObject?)>?
    
    init(parent: ModelObject, key: String) {
        self.parent = parent
        self.key = key
    }
}

public func ==(lhs: ParentRelationship, rhs: ParentRelationship) -> Bool {
    return lhs.parent == rhs.parent && lhs.key == rhs.key
}

private var voidContext = 0

struct PropertyInfo {
    let key: String
    let valueType: ModelValueType
    let defaultValue: AnyObject?
    let acceptsNil: Bool
}

@objc public class ModelObject: NSObject {
    public let onPropertyChange = Signal<(key: String, oldValue: AnyObject?, value: AnyObject?)>()
    public let onModelAddedToCollection = Signal<(key: String, element: AnyObject, atIndex:Int)>()
    public let onModelRemovedFromCollection = Signal<(key: String, element: AnyObject, atIndex:Int)>()
    public let onDetachedFromScope = Signal<(Scope)>()
    public let onAttachToScope = Signal<(Scope)>()
    public let onAddedParent = Signal<(parent: ModelObject, key: String)>()
    public let onRemovedParent = Signal<(parent: ModelObject, key: String)>()
    public let onTreeChange = Signal<()>()
    
    let className: String!
    
    struct Static {
        static var allTypes = [String: AnyClass]()
        static var compositeDependencies = [String: [String: [String]]]()
        static var propertiesInitialzedForClasses = [String: Bool]()
        static var properties = [String: [String: PropertyInfo]]()
    }
    
    class func classNameWithType(type: AnyClass) -> String {
        let name = NSStringFromClass(type)
        
        // Warning: Just assuming that Swift will forever have a prefix followed by a dot and the classname
        let components = name.componentsSeparatedByString(".")
        return components[components.count-1]
    }

    override public class func initialize() {
        Static.allTypes[classNameWithType(self)] = self
        
        let name = NSStringFromClass(self)
        
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
        Static.properties[name] = [String: PropertyInfo]()
    }
    
    public class func getCompositeDependencies() -> [String: [String]] {
        return [String :[String]]()
    }
    
    public internal(set) var uuid: NSUUID
    
    var properties: [String: PropertyInfo] {
        return Static.properties[className]!
    }
    
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
    public internal(set) var scope: Scope? {
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
    
    private var internalTreeInvalidated = false
    var treeInvalidated: Bool {
        get {
            return internalTreeInvalidated
        }
        set {
            if (internalTreeInvalidated != newValue) {
                internalTreeInvalidated = newValue
                if internalTreeInvalidated == true {
                    delay(0.0) { [weak self] () -> () in
                        if let definiteSelf = self {
                            definiteSelf.treeInvalidated = false
                            definiteSelf.onTreeChange.fire()
                        }
                    }
                    for parentRelationship in parents {
                        parentRelationship.parent.treeInvalidated = true
                    }
                }
            }
        }
    }

    public override init() {
        uuid = NSUUID()
        super.init()
        className = ModelObject.classNameWithType(self.dynamicType)
        setupPropertyListeners()
    }
    
    required public init(uuid: NSUUID) {
        self.uuid = uuid
        super.init()
        className = ModelObject.classNameWithType(self.dynamicType)
        setupPropertyListeners()
    }
    
    convenience init(uuidString: String) {
        if let uuid = NSUUID(UUIDString: uuidString) {
            self.init(uuid: uuid)
        } else {
            self.init(uuid: NSUUID())
        }
    }
    
    deinit {
        for property in properties.values {
            removeObserver(self, forKeyPath: property.key)
        }
    }
    
    // MARK: - Public Interface
    
    /// Assigns a scope to the model object and makes it the new root for the scope.
    ///
    /// :param: scope The scope to add the model object to.
    public func setScopeAndMakeRootModel(scope: Scope) {
        detach()
        internalIsScopeRoot = true
        self.scope = scope
    }
    
    /// Creates a scope and a sync client with the specified transport adapter and once connected will issue
    /// a scope fetch request and begin syncing this ModelObject with the server on the specified scope.
    /// You can provide params for both the session it creates and the scope fetch request that is issued.
    ///
    /// :param: scopeName The scope name.
    /// :param: adapter The transport adapter the sync client should use.
    /// :param: sessionCreateParams Any params that should be sent along with the session create request.
    /// :param: scopeFetchParams Any params that should be sent along with the scope fetch request.
    /// :param: scopeFetchAttemptCallback Will be called once either the session was either denied or accepted and syncing began.
    public func syncWithScopeName(scopeName: String, adapter: TransportAdapter, sessionCreateParams: [String: AnyObject], scopeFetchParams: [String: AnyObject], scopeFetchAttemptCallback: (NSError?, Client) -> ()) {
        let scope = Scope(name: scopeName)
        setScopeAndMakeRootModel(scope)
        
        let client = Client(transportAdapter: adapter)
        client.connectWithSessionCreateParams(sessionCreateParams)
        
        var sessionAcceptedListener: SignalListener<Session>?
        var sessionDeniedListener: SignalListener<Void>?
        sessionAcceptedListener = client.onSession.listenOnce(self) { session in
            sessionDeniedListener?.cancel()
            session.fetch(scope, params: scopeFetchParams) { error in
                scopeFetchAttemptCallback(error, client)
            }
        }
        sessionDeniedListener = client.onSessionDenied.listenOnce(self) {
            sessionAcceptedListener?.cancel()
            scopeFetchAttemptCallback(error(.SessionDenied), client)
        }
    }
    
    /// Creates a scope and a sync client with the specified transport adapter and once connected will issue
    /// a scope fetch request and begin syncing this ModelObject with the server on the specified scope.
    /// You can provide params for the session it creates.
    ///
    /// :param: scopeName The scope name.
    /// :param: adapter The transport adapter the sync client should use.
    /// :param: scopeFetchAttemptCallback Will be called once either the session was either denied or accepted and syncing began.
    public func syncWithScopeName(scopeName: String, adapter: TransportAdapter, scopeFetchAttemptCallback: (NSError?, Client) -> ()) {
        syncWithScopeName(scopeName,
            adapter: adapter,
            sessionCreateParams: [String: AnyObject](),
            scopeFetchParams: [String: AnyObject](),
            scopeFetchAttemptCallback: scopeFetchAttemptCallback)
    }
    
    /// Creates a scope and a sync client with the specified transport adapter and once connected will issue
    /// a scope fetch request and begin syncing this ModelObject with the server on the specified scope.
    ///
    /// :param: scopeName The scope name.
    /// :param: adapter The transport adapter the sync client should use.
    /// :param: sessionCreateParams Any params that should be sent along with the session create request.
    /// :param: scopeFetchAttemptCallback Will be called once either the session was either denied or accepted and syncing began.
    public func syncWithScopeName(scopeName: String, adapter: TransportAdapter, sessionCreateParams: [String: AnyObject], scopeFetchAttemptCallback: (NSError?, Client) -> ()) {
        syncWithScopeName(scopeName,
            adapter: adapter,
            sessionCreateParams: sessionCreateParams,
            scopeFetchParams: [String: AnyObject](),
            scopeFetchAttemptCallback: scopeFetchAttemptCallback)
    }
    
    /// Invokes a callback whenever any property or collection on the object has changed. This observer waits until the next runloop to
    /// dispatch and merges any changes that happen during the current runloop to dispatch changes only once.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: callback A closure that gets executed whenever any property or collection on the object has changed.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChange(observer: AnyObject, callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: nil, delay: true, callback: callback)
    }
    
    /// Immediately invokes a callback whenever any property or collection on the object changes. This will happen for every single property
    /// change. To get a distilled callback once every runloop, use the observeChange callback instead.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: callback A closure that gets executed every time any property or collection of the object changes.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChangeImmediately(observer: AnyObject, callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: nil, delay: false, callback: callback)
    }
    
    /// Invokes a callback whenever any specific property or collection on the object has changed. This observer waits until the next
    /// runloop to dispatch and merges any changes that happen during the current runloop to dispatch changes only once.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: key The key of the property to listen to.
    /// :param: callback A closure that gets executed whenever the provided property has changed.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChange(observer: AnyObject, key: String, callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: [key], delay: true, callback: callback)
    }
    
    /// Immediately invokes a callback whenever a specific property or collection on the object changes. This will happen for every single
    /// change. To get a distilled callback once every runloop, use the observeChange callback instead.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: key The key of the property to listen to.
    /// :param: callback A closure that gets executed every time the provided property changes.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChangeImmediately(observer: AnyObject, key: String, callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: [key], delay: false, callback: callback)
    }
    
    /// Invokes a callback whenever any of the specified properties or collections have changed. This observer waits until the next
    /// runloop to dispatch and merges any changes that happen during the current runloop to dispatch changes only once.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: keys An array of keys to listen to.
    /// :param: callback A closure that gets executed whenever any of the provided properties or collections have changed.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChange(observer: AnyObject, keys: [String], callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: keys, delay: true, callback: callback)
    }
    
    /// Immediately invokes a callback whenever any of the specified properties or collections change. This will happen for every single
    /// change of any of the provided properties. To get a distilled callback once every runloop, use the observeChange callback instead.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: keys An array of keys to listen to.
    /// :param: callback A closure that gets executed every time any of the provided properties or collections change.
    /// :returns: A function that cancels the observation when invoked.
    public func observeChangeImmediately(observer: AnyObject, keys: [String], callback: () -> Void) -> CancelObserver {
        return observeChange(observer, keys: keys, delay: false, callback: callback)
    }
    
    /// Invokes a callback when the object or any of its children change. This observer waits until the next runloop to
    /// dispatch and merges any changes that happen during the current runloop to dispatch changes only once.
    ///
    /// :param: observer A listener to attach to the event.
    /// :param: callback A closure that gets executed whenever the object or any of its children and children's children change.
    /// :returns: A function that cancels the observation when invoked.
    public func observeTreeChange(observer: AnyObject, callback: () -> Void) -> CancelObserver {
        let listener = onTreeChange.listen(observer) { callback() }
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever a specific collection adds an element.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: key The key of the the collection to listen to.
    /// :param: callback The closure that gets executed every time the collection adds an element. Set the type of the element
    /// in the callback to the appropriate type of the collection.
    /// :returns: A function that cancels the observation when invoked.
    public func observeCollectionAdd<T>(listener: AnyObject, key: String, callback: (element: T) -> Void) -> CancelObserver {
        assert(properties[key] != nil, "no property found for key '\(key)'")
        assert(properties[key]!.valueType == ModelValueType.Array, "property '\(key)' is not an Array")
        
        let listener = onModelAddedToCollection.listen(listener) { (key, element, atIndex) -> Void in
            if let definiteElement = element as? T {
                callback(element: element as T)
            }
            }.filter { $0.key == key}
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever a specific collection removes an element.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: key The key of the the collection to listen to.
    /// :param: callback The closure that gets executed every time the collection removes an element. Set the type of the element
    /// in the callback to the appropriate type of the collection.
    /// :returns: A function that cancels the observation when invoked.
    public func observeCollectionRemove<T>(listener: AnyObject, key: String, callback: (element: T) -> Void) -> CancelObserver {
        assert(properties[key] != nil, "no property found for key '\(key)'")
        assert(properties[key]!.valueType == .Array, "property '\(key)' is not an Array")
        
        let listener = onModelRemovedFromCollection.listen(listener) { (key, element, atIndex) -> Void in
            if let definiteElement = element as? T {
                callback(element: element as T)
            }
            }.filter { return $0.key == key }
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever the ModelObject is attached to a scope.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope. The scope argument
    /// contains the scope to which the model object was attached to.
    /// :returns: A function that cancels the observation when invoked.
    public func observeAttach(listener: AnyObject, callback: (scope: Scope) -> Void) -> CancelObserver {
        let listener = onAttachToScope.listen(listener)  { (scope) -> Void in
            callback(scope: scope)
        }
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever the ModelObject is attached to a scope.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is added to a scope. The scope argument
    /// contains the scope from which the model object was removed from.
    /// :returns: A function that cancels the observation when invoked.
    public func observeDetach(listener: AnyObject, callback: (scope: Scope) -> Void) -> CancelObserver {
        let listener = onDetachedFromScope.listen(listener)  { (scope) -> Void in
            callback(scope: scope)
        }
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever the ModelObject is moved between scopes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is moved between scopes. The scope argument
    /// contains the new scope of the model object.
    /// :returns: A function that cancels the observation when invoked.
    public func observeAddedToParent(listener: AnyObject, callback: (parent: ModelObject, key: String) -> Void) -> CancelObserver {
        let listener = onAddedParent.listen(listener) { (parent, key) -> Void in
            callback(parent: parent, key:key)
        }
        return { listener.cancel() }
    }
    
    /// Fires a listener whenever the ModelObject is moved between scopes.
    ///
    /// :param: listener The listener to attach to the event.
    /// :param: callback The closure that gets executed every time the ModelObject is moved between scopes.
    /// :returns: A function that cancels the observation when invoked.
    public func observeRemovedFromParent(listener: AnyObject, callback: (parent: ModelObject, key: String) -> Void) -> CancelObserver {
        let listener = onRemovedParent.listen(listener) { (parent, key) -> Void in
            callback(parent: parent, key: key)
        }
        return { listener.cancel() }
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
    
    // MARK: - Internal Interface
    func setupPropertyListeners() {
        if Static.propertiesInitialzedForClasses[className] == nil {
            Static.propertiesInitialzedForClasses[className] = true
            
            var trackedProperties = [String: PropertyInfo]()
            
            let propertyDependencies = self.dynamicType.getCompositeDependencies()
            var propertyCount: UInt32 = 0
            let propertyList = class_copyPropertyList(self.dynamicType, &propertyCount)
            
            for i in 0..<Int(propertyCount) {
                var propertyCName = property_getName(propertyList[i])
                if propertyCName != nil {
                    let propertyName = NSString(CString: propertyCName, encoding: NSString.defaultCStringEncoding()) as String
                    let propertyAttributes = property_getAttributes(propertyList[i])
                    let attributes = NSString(CString: propertyAttributes, encoding: NSString.defaultCStringEncoding()) as String
                    
                    let components = attributes.componentsSeparatedByString(",")
                    
                    if components.count > 2 {
                        var type: NSString = (components[0] as NSString).substringFromIndex(1)
                        var writeable = (components[2] as String) != "R"
                        
                        var valueType: ModelValueType?
                        
                        if propertyDependencies[propertyName] != nil {
                            valueType = .Composite
                        } else if let asArray = self.valueForKey(propertyName) as? [ModelObject] {
                            valueType = .Array
                        } else if let definiteValueType = ModelValueType(rawValue: type) {
                            valueType = definiteValueType
                        } else if type.rangeOfString("@\"").location != NSNotFound {
                            // Assuming that every custom object type extends from ModelObject
                            valueType = .ModelObject
                        }
                        
                        if let definiteValueType = valueType {
                            if writeable || definiteValueType == ModelValueType.Composite {
                                let defaultValue: AnyObject? = valueForKey(propertyName)
                                
                                // TODO: Check if property is an optional
                                var acceptsNil = modelValueIsNillable(definiteValueType)
                                
                                trackedProperties[propertyName] = PropertyInfo(key: propertyName, valueType: definiteValueType, defaultValue: defaultValue, acceptsNil: acceptsNil)
                            }
                        }
                    }
                }
            }
            free(propertyList)
            Static.properties[className] = trackedProperties
        }
        
        for (propertyName, propertyInfo) in properties {
            addObserver(self, forKeyPath: propertyName, options: .New | .Old, context: &voidContext)
        }
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
                    if (key == relationship.key) {
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
            
            onAddedParent.fire((parent: parentRelationship.parent, key: parentRelationship.key))

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
            parentRelationship.parent.removeChildAtKey(parentRelationship.key, child: self)
            if (parents.count == 0) {
                scope = nil
            }
        }
    }

    func removeChildAtKey(key: String, child: ModelObject) {
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
    
    func keyChanged(key: String, oldValue: AnyObject?, newValue: AnyObject?) {
        let newArray = newValue as? [ModelObject]
        let oldArray = oldValue as? [ModelObject]
        
        if newArray != nil && oldArray != nil {
            var index: Int = 0
        
            // TODO: Optimize this
            for index in 0 ..< oldArray!.count {
                if !contains(newArray!, oldArray![index]) {
                    let model = oldArray![index]
                    model.removeParentRelationship(ParentRelationship(parent: self, key: key))
                    onModelRemovedFromCollection.fire(key: key, element: model as AnyObject, atIndex: index)
                }
            }
            for index in 0 ..< newArray!.count {
                if !contains(oldArray!, newArray![index]) {
                    let model = newArray![index]
                    model.addParentRelationship(ParentRelationship(parent: self, key: key))
                    onModelAddedToCollection.fire(key: key, element: model as AnyObject, atIndex: index)
                }
            }
        } else if let modelObject = newValue as? ModelObject {
            modelObject.addParentRelationship(ParentRelationship(parent: self, key: key))
        }
        
        onPropertyChange.fire(key: key, oldValue: oldValue, value: newValue)
        
        if let dependencies = dependenciesForKey(key) {
            for dependency in dependencies {
                onPropertyChange.fire(key: dependency, oldValue: nil, value: nil)
            }
        }
        treeInvalidated = true
    }

    override public func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
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
                keyChanged(keyPath, oldValue: oldValue, newValue: newValue)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    private func observeChange(observer: AnyObject, keys: [String]?, delay: Bool, callback: () -> Void) -> CancelObserver {
        assert(keys == nil || keys!.count > 0, "no key specified")
        assert(keys == nil || keys!.filter { self.properties[$0] == nil }.count == 0, "no property found for \(keys!.filter { self.properties[$0] != nil })")
        
        let listener = onPropertyChange.listen(observer) { (key, oldValue, value) -> Void in
            callback()
        }
        if let definiteKeys = keys {
            if definiteKeys.count == 1 {
                let key = definiteKeys[0]
                listener.filter { $0.key == key }
            } else {
                var lookup = [String: Bool]()
                for key in definiteKeys {
                    lookup[key] = true
                }
                listener.filter { lookup[$0.key] != nil}
            }
        }
        if delay {
            listener.queueAndDelayBy(0.0)
        }
        return { listener.cancel() }
    }
}
