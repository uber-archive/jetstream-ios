//
//  ModelValue.swift
//  Jetstream
//
//  Created by Tuomas Artman on 10/7/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

protocol ModelValue {
    func equalTo(value: ModelValue) -> Bool
}

enum ModelValueType: String {
    case Int8 = "c"
    case UInt8 = "C"
    case Int16 = "s"
    case UInt16 = "S"
    case Int32 = "i"
    case UInt32 = "I"
    case Int = "q"
    case UInt = "Q"
    case Float = "f"
    case Double = "d"
    case Bool = "b"
    case Str = "@"
    case Array = "@a"
    case ModelObject = "@m"
}

func convertAnyObjectToModelValue(value: AnyObject, type: ModelValueType) -> ModelValue? {
    switch type {
    case .Int8: return value as? Int
    case .UInt8: return value as? Int
    case .Int16: return value as? Int
    case .UInt16: return value as? Int
    case .Int32: return value as? Int
    case .UInt32: return value as? Int
    case .Int: return value as? Int
    case .UInt: return value as? UInt
    case .Float: return value as? Float
    case .Double: return value as? Double
    case .Bool: return value as? Bool
    case .Str: return value as? String
    case .Array: return value as? [AnyObject]
    case .ModelObject: return value as? ModelObject
    }
}

extension String: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as String }
}

extension UInt: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as UInt }
}

extension Int: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Int }
}

extension UInt8: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as UInt8 }
}

extension Int8: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Int8 }
}

extension UInt16: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as UInt16 }
}

extension Int16: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Int16 }
}

extension UInt32: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as UInt32 }
}

extension Int32: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Int32 }
}

extension Float: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Float }
}

extension Double: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Double }
}

extension Bool: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as Bool }
}

extension Array: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return false }
}

extension ModelObject: ModelValue {
    func equalTo(value: ModelValue) -> Bool { return self == value as ModelObject }
}

