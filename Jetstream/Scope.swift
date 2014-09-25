//
//  Scope.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public class Scope {

    public var name: String
    var modelObjects: [ModelObject] = Array()
    var modelHash = Dictionary<NSUUID, ModelObject>()
    
    init(name: String) {
        self.name = name
    }
    
    func addModelObject(object: ModelObject) {
        modelObjects.append(object)
        modelHash[object.uuid] = object
    }
    
    func removeModelObject(object: ModelObject) {
        modelObjects = modelObjects.filter { $0 != object }
        modelHash.removeValueForKey(object.uuid)
    }
    
    // MARK: - Public API
    
    public func getObjectById(uuid: NSUUID) -> ModelObject? {
        return modelHash[uuid]
    }
    
    public func getObjectById(uuidString: String) -> ModelObject? {
        if let uuid = NSUUID(UUIDString: uuidString) {
            return getObjectById(uuid)
        }
        return nil
    }
}
