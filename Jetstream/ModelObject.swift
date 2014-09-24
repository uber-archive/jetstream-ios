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
public func !=(lhs: ParentRelationship, rhs: ParentRelationship) -> Bool {
    return !(lhs.parent == rhs.parent)
}


private var myContext = 0

@objc public class ModelObject: NSObject {

    public let onPropertyChange = Signal<(keyPath: String, value: AnyObject?)>()
    public let onDetach = Signal<(parent: ModelObject, keyPath: String)>()
    public let onAttach = Signal<(parent: ModelObject, keyPath: String)>()
    public let onMove = Signal<(parent: ModelObject, keyPath: String)>()
    
    private var properties: [String] = []
    
    public var root: Bool = false {
        didSet {
            if (root != oldValue) {
                attached = root
                parent = nil
            }
        }
    }
    
    private var _attached: Bool = false
    private var attached: Bool {
        get {
            return _attached
        }
        
        set(value) {
            if (_attached != value) {
                _attached = value
                if let definiteParent = parent {
                    if (attached) {
                        onAttach.fire(parent: definiteParent.parent, keyPath: definiteParent.keyPath)
                    } else {
                        onDetach.fire(parent: definiteParent.parent, keyPath: definiteParent.keyPath)
                    }
                }
                
                for child in childModelObjects {
                    if (child != self) {
                        child.attached = attached
                    }
                }
            }
        }
    }

    public var parent: ParentRelationship? {
        willSet(newValue) {
            if (parent != newValue) {
                println("Will set \(parent) to \(newValue)")
                if let definiteParent = parent {
                    definiteParent.parent.onPropertyChange.removeListener(self)
                }
                if newValue == nil && !root {
                    attached = false
                }
            }
        }
        
        didSet(oldValue) {
            if (parent != oldValue) {
                if let newParent = parent {
                    newParent.parent.onPropertyChange.listen(self, callback: { (keyPath, value) -> Void in
                        if (keyPath == newParent.keyPath) {
                            if (value as? ModelObject) != self {
                                self.parent = nil
                            }
                        }
                    })
                    if oldValue != nil && oldValue!.parent.attached {
                        onMove.fire(parent: newParent.parent, keyPath: newParent.keyPath)
                    }
                }
                if let definiteOldParent = oldValue {
                    definiteOldParent.parent.setValue(nil, forKey: definiteOldParent.keyPath)
                }
                if let definiteParent = parent {
                    attached = definiteParent.parent.attached
                }
            }
        }
    }
    
    private var childModelObjects: [ModelObject] {
        get {
            var objects = Array<ModelObject>()
            for property in properties {
                if let modelObject = self.valueForKey(property) as? ModelObject {
                    objects.append(modelObject)
                }
            }
            return objects
        }
    }

    public override init() {
        super.init()
        
        let mirror = reflect(self)
        for i in 0...mirror.count - 1 {
            var (name, type) = mirror[i]
            if name != "super" {
                properties.append(name)
                self.addObserver(self, forKeyPath: name, options: .New | .Old, context: &myContext)
            }
        }
    }
    
    deinit {
        for property in properties {
            removeObserver(self, forKeyPath: property)
        }
    }
    
    private func keyPathChanged(keyPath: String, oldValue: AnyObject?, newValue: AnyObject?) {
        onPropertyChange.fire(keyPath: keyPath, value: newValue)
        if let modelObject = newValue as? ModelObject {
            modelObject.parent = ParentRelationship(parent: self, keyPath: keyPath)
            modelObject.attached = attached
        }
    }
    
    func sameClass (object1: AnyObject, object2: AnyObject) -> Bool {
        return (object_getClassName(object1) == object_getClassName(object2))
    }
    
    override public func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if context == &myContext {
            keyPathChanged(keyPath, oldValue: change[NSKeyValueChangeOldKey], newValue: change[NSKeyValueChangeNewKey])
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: - Public API
    
    public func onChange(listener: AnyObject, keyPath: String, callback: () -> Void) {
        let listener = onPropertyChange.listen(listener, callback: { (keyPath, value) -> Void in
            callback()
        })
        listener.setFilter { (changedKeyPath, value) -> Bool in
            return keyPath == changedKeyPath
        }
    }
    
    public func onChange(listener: AnyObject, keyPaths: [String], callback: () -> Void) {
        let listener = onPropertyChange.listen(listener, callback: { (keyPath, value) -> Void in
            callback()
        })
        listener.setFilter { (changedKeyPath, value) -> Bool in
            return keyPaths.reduce(false, combine: { return $0 || $1 == changedKeyPath })
        }
    }
}

