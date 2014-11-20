//
//  Shape.swift
//  JetstreamDemos
//
//  Created by Tuomas Artman on 9/26/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Jetstream

class Shape: ModelObject {
    dynamic var x: CGFloat = 100
    dynamic var y: CGFloat = 100
    dynamic var width: CGFloat = 100
    dynamic var height: CGFloat = 100
    dynamic var color: UIColor = shapeColors[0]
}

let shapeColors = [
    "#1dd2af", "#19b698", "#40d47e", "#2cc36b", "#4aa3df", "#2e8ece",
    "#a66bbe", "#9b50ba", "#3d566e", "#354b60", "#f2ca27", "#f4a62a",
    "#e98b39", "#ec5e00", "#ea6153", "#d14233", "#8c9899"
].map { UIColor.colorWithHexString($0) }
