//
//  Extensions.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/30/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

extension Dictionary {
    
    func valueForKey<T>(key: Key) -> T? {
        if let value = self[key] as? T {
            return value
        } else {
            return nil
        }
    }
    
}
