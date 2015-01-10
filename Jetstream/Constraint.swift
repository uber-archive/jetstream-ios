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

/// The has new value property constraint is used to describe a property value has a new value.  That is that this
/// property has a new value described by the change.
public class HasNewValuePropertyConstraint {
    public init() {
        // No-op
    }
}

/// An array property constraint type is used to describe a type of constraint on a new array property value.
public enum ArrayPropertyConstraintType {
    case Insert
    case Remove
}

/// An array property constraint is used to describe a constraint on a new array property value.  In future it should
/// support actually specifying things like the insert or removal index, etc.
public class ArrayPropertyConstraint {
    let type: ArrayPropertyConstraintType

    public init(type: ArrayPropertyConstraintType) {
        self.type = type
    }
}

/// A constraint is used to describe a change that must target a change or add of a certain model and can specify 
/// that the change sets properties to certain values or transforms them in specified manner.
public class Constraint {
    /// The type of SyncFragment to target for constraint.
    public let type: SyncFragmentType
    
    /// The model class name to target for constraint.
    public let clsName: String
    
    /// The property values that must match for this constraint to pass. For simple checking of properties receiving 
    /// new values you can use a HasNewValuePropertyConstraint as a value for the property name. For array properties 
    /// you can use an ArrayPropertyConstraint as a value in place of the actual value to describe the transform the 
    /// array should be applying as part of the constraint.
    public let properties: [String: AnyObject]
    
    /// Whether to allow additional properties than specified to pass the constraint.
    public let allowAdditionalProperties: Bool
    
    /// Validates that a set of constraints matches a set of SyncFragments.
    ///
    /// :param: constraints The constraints to apply.
    /// :param: syncFragments The sync fragments to apply the constraints on.
    public class func matchesAllConstraints(constraints: [Constraint], syncFragments: [SyncFragment]) -> Bool {
        var unmatchedFragments = syncFragments
        
        for constraint in constraints {
            // Remove fragments in batches so each fragment has an accounted for constraint
            unmatchedFragments = unmatchedFragments.filter { !constraint.matches($0) }
        }
        
        return unmatchedFragments.count == 0
    }
    
    /// Constructs the Constraint.
    ///
    /// :param: type The type of SyncFragment to target for constraint.
    /// :param: clsName The model class name to target for constraint.
    /// :param: properties The property values that must match for this constraint to pass.
    /// :param: allowAdditionalProperties Whether to allow additional properties than specified to pass the constraint.
    public init(type: SyncFragmentType, clsName: String, properties: [String: AnyObject] = [String: AnyObject](), allowAdditionalProperties: Bool = true) {
        self.type = type
        self.clsName = clsName
        self.properties = properties
        self.allowAdditionalProperties = allowAdditionalProperties
    }
    
    /// Validates that the constraint matches a SyncFragment.
    ///
    /// :param: syncFragment The sync fragment to validate the constraint matches.
    public func matches(syncFragment: SyncFragment) -> Bool {
        if type != syncFragment.type || syncFragment.clsName == nil || clsName != syncFragment.clsName! {
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
                    // Ensure count matches if not allowing additional properties
                    if !allowAdditionalProperties && self.properties.count != fragmentProperties.count {
                        // Not allowing additional properties, needs to match count.  If other mismatch a property 
                        // will be missing from fragment properties and it will be caught by the checking below.
                        return false
                    }
                    
                    // Iterate over constraints
                    for (constraintKey, constraintValue) in self.properties {
                        
                        // Extract fragment value and property info for this constraint key
                        if let value: AnyObject = fragmentProperties[constraintKey] {
                            if let propertyInfo = propertyInfos[constraintKey] {
                                // Check value matches constraint
                                if let hasNewValueConstraintValue = constraintValue as? HasNewValuePropertyConstraint {
                                    // Apply a simple check to make sure this change has a new model value
                                    let fragmentModelValue = convertAnyObjectToModelValue(value, propertyInfo.valueType)
                                    if value !== NSNull() && fragmentModelValue == nil {
                                        return false
                                    }
                                } else if let arrayConstraintValue = constraintValue as? ArrayPropertyConstraint {
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
                    return true
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
