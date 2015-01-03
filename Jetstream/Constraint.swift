//
//  Constraint.swift
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

public enum ArrayConstraintOperationType {
    case Insert
    case Remove
}

public class ArrayConstraintOperation {
    let type: ArrayConstraintOperationType

    public init(type: ArrayConstraintOperationType) {
        self.type = type
    }
}

public class Constraint {
    /// Validates that a set of constraints matches a set of SyncFragments
    ///
    /// :param: constraints The constraints to apply
    /// :param: syncFragments The sync fragments to apply the constraints on
    public class func matchesAll(constraints: [Constraint], syncFragments: [SyncFragment]) -> Bool {
        // Take a shallow copy of the sync fragments
        var unmatchedFragments = syncFragments.map { $0 }
        
        for constraint in constraints {
            // Remove fragments in batches so each fragment has an accounted for constraint
            unmatchedFragments = unmatchedFragments.filter { !constraint.matches($0) }
        }
        
        return unmatchedFragments.count == 0
    }
    
    public let type: SyncFragmentType
    public let clsName: String
    public let properties: [String: AnyObject]
    public let allowAdditionalProperties: Bool
    
    public init(type: SyncFragmentType, clsName: String, properties: [String: AnyObject] = [String: AnyObject](), allowAdditionalProperties: Bool = true) {
        self.type = type
        self.clsName = clsName
        self.properties = properties
        self.allowAdditionalProperties = allowAdditionalProperties
    }
    
    public func matches(syncFragment: SyncFragment) -> Bool {
        if type != syncFragment.type || clsName != syncFragment.clsName {
            // Does not match constraint type and class
            return false
        }
        
        if properties.count < 1 {
            if !allowAdditionalProperties && syncFragment.properties != nil && syncFragment.properties!.count > 0 {
                // Expecting no properties however there are some
                return false
            } else {
                // Matches as no constraint values to verify
                return true
            }
        }
        
        // Extract class property infos and fragment properties
        if let clsName = syncFragment.clsName {
            if let propertyInfos = ModelObject.Static.properties[clsName] {
                if let fragmentProperties = syncFragment.properties {
                    
                    // Iterate over constraints
                    for (constraintKey, constraintValue) in self.properties {
                        
                        // Extract fragment value and property info for this constraint key
                        if let value: AnyObject = fragmentProperties[constraintKey] {
                            if let propertyInfo = propertyInfos[constraintKey] {
                                // Check value matches constraint
                                if let arrayConstraintValue = constraintValue as? ArrayConstraintOperation {
                                    // Apply an array constraint value
                                    if let array = value as? [AnyObject] {
                                        switch type {
                                        case .Add:
                                            if arrayConstraintValue.type != .Insert || array.count < 1 {
                                                // Allow an insert constraint on an add with actual values in the 
                                                // array but not a remove or anything else as they do not make sense
                                                return false
                                            }
                                        case .Change:
                                            if let originalArray = syncFragment.originalProperties?[constraintKey] as? [AnyObject] {
                                                if arrayConstraintValue.type == .Insert && !(array.count > originalArray.count) {
                                                    return false
                                                } else if arrayConstraintValue.type == .Remove && !(array.count < originalArray.count) {
                                                    return false
                                                }
                                            } else {
                                                return false
                                            }
                                        }
                                    } else {
                                        return false
                                    }
                                } else {
                                    // Apply a simple value constraint
                                    if constraintValue === NSNull() && value === NSNull() {
                                        // Allow case where constraint is nil and explicit nil matches
                                    } else {
                                        let constraintModelValue = convertAnyObjectToModelValue(constraintValue, propertyInfo.valueType)
                                        let fragmentModelValue = convertAnyObjectToModelValue(value, propertyInfo.valueType)
                                        if constraintModelValue == nil || fragmentModelValue == nil {
                                            return false
                                        } else if !constraintModelValue!.equalTo(fragmentModelValue!) {
                                            return false
                                        }
                                    }
                                }
                            } else {
                                // Cannot check values as no propertyInfo for key for this class
                                return false
                            }
                        } else {
                            // Specified a constraint at a key which fragment does not include
                            return false
                        }
                    }
                    
                    // All constraint values passed
                    if !allowAdditionalProperties && self.properties.count != fragmentProperties.count {
                        // Not allowing additional properties and after successful checks remaining properties
                        return false
                    } else {
                        // Either allow additional properties or the count was the same and all checked
                        return true
                    }
                } else {
                    // Had constraints we couldn't compare because fragment has no properties
                    return false
                }
            } else {
                // Could not lookup property infos
                return false
            }
        } else {
            // Could not lookup class name for property infos
            return false
        }
    }
}
