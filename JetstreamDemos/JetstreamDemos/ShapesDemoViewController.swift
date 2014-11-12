//
//  ShapesDemoViewController.swift
//  JetstreamDemos
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

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
        
        let transportAdapter = WebsocketTransportAdapter(options: WebsocketConnectionOptions(url: NSURL(string: "ws://" + host + ":3000")!))
        client = Client(transportAdapter: transportAdapter)
        client?.connect()
        client?.onSession.listenOnce(self) { [weak self] session in
            if let definiteSelf = self {
                definiteSelf.sessionDidStart(session)
            }
        }
    }
    
    func sessionDidStart(session: Session) {
        self.session = session
        session.fetch(scope) { (error) in
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
