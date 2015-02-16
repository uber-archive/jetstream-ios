//
//  ShapesDemoViewController.swift
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
import UIKit
import Jetstream

class ShapesDemoViewController: UIViewController, NSURLConnectionDataDelegate {
    var scope = Scope(name: "Canvas")
    var canvas = Canvas()

    var client: Client?
    var session: Session?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shapes Demo"

        let tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleTap:"))
        self.view.addGestureRecognizer(tapRecognizer)

        scope.root = canvas
        canvas.observeCollectionAdd(self, key: "shapes") { (element: Shape) in
            let shapeView = ShapeView(shape: element)
            self.view.addSubview(shapeView)
        }
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        let shape = Shape()
        shape.color = shapeColors[Int(arc4random_uniform(UInt32(shapeColors.count)))]
        var point = recognizer.locationInView(self.view)
        shape.x = point.x - shape.width / 2
        shape.y = point.y - shape.height / 2
        canvas.shapes.append(shape)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        showLoader()
        
        let options = WebSocketConnectionOptions(url: NSURL(string: "ws://" + host + ":3000")!)
        client = Client(transportAdapterFactory: { WebSocketTransportAdapter(options: options) })
        client?.connect()
        client?.onSession.listenOnce(self) { [unowned self] in self.sessionDidStart($0) }
    }
    
    func sessionDidStart(session: Session) {
        self.session = session
        session.fetch(scope) { error in
            if error != nil {
                self.alertError("Error fetching scope", message: "\(error)")
            } else {
                self.hideLoader()
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        hideLoader()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        client?.onSession.removeListener(self)
        client?.close()
        client = nil
    }
}
