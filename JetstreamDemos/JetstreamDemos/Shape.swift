//
// Shape.swift
// Jetstream
// 
// Copyright (c) 2014 Uber Technologies, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

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
