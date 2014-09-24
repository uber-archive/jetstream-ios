//
//  TestModel.swift
//  Jetstream
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

@objc class TestModel: ModelObject {
    dynamic var string: String? = ""
    dynamic var integer = 0
    dynamic var float = 0
    dynamic var array: [String] = []
    dynamic var nsArray = NSMutableArray()
    dynamic var childModel: TestModel?
    dynamic var childModel2: TestModel?
}