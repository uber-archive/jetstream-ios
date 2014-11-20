//
// ScopeFetchMessage.swift
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

class ScopeFetchMessage: NetworkMessage {
    class var messageType: String {
        return "ScopeFetch"
    }
    
    override var type: String {
        return ScopeFetchMessage.messageType
    }
    
    let name: String
    let params: [String: AnyObject]
    
    init(index: UInt, name: String, params: [String: AnyObject]) {
        self.name = name
        self.params = params
        super.init(index: index)
    }
    
    convenience init(session: Session, name: String) {
        self.init(index: session.getNextMessageIndex(), name: name, params: [String: AnyObject]())
    }
    
    convenience init(session: Session, name: String, params: [String: AnyObject]) {
        self.init(index: session.getNextMessageIndex(), name: name, params: params)
    }
    
    override func serialize() -> [String: AnyObject] {
        var dictionary = super.serialize()
        dictionary["name"] = name
        dictionary["params"] = params
        return dictionary
    }
}
