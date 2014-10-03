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
    
    struct Static {
        static let host = "localhost"
    }
    
    var scope = Scope(name: "ShapesDemo")
    var shapesDemo = ShapesDemo()
    
    var headers = [String: String]()
    var client: Client?
    var session: Session?
    var appearing = false
    var loader: UIView?
    
    override func viewDidLoad() {
        title = "Shapes Demo"

        let tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleTap:"))
        self.view.addGestureRecognizer(tapRecognizer)
        
        shapesDemo.setScopeAndMakeRootModel(scope)
        shapesDemo.observeCollectionAdd(self, keyPath: "shapes") { (element: Shape) in
            let shapeView = ShapeView(shape: element)
            self.view.addSubview(shapeView)
        }
    }
    
    func connect() {
        client = Client(options: MQTTLongPollChunkedConnectionOptions(
            receiveURL: "http://" + Static.host + ":3000/mqtt/lpc/connect",
            sendURL: "http://" + Static.host + ":3000/mqtt/lpc/send",
            headers: headers,
            sendIdRequired: true))
        client?.connect()
        client?.onSession.listenOnce(self) { (session) in
            self.session = session
            let scope = self.scope
            session.fetch(scope) { (error) in
                if error != nil {
                    NSLog("Request scope error: %@", error!)
                } else {
                    NSLog("Retrieved scope")
                    self.removeLoader()
                }
            }
            NSLog("Got session with token: %@", session.token)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        client?.onSession.removeListener(self)
        client?.close()
        client = nil
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        let shape = Shape()
        var point = recognizer.locationInView(self.view)
        shape.x = point.x - shape.width / 2
        shape.y = point.y - shape.height / 2
        shapesDemo.shapes.append(shape)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        appearing = true
        
        if loader != nil {
            removeLoader()
        }
        var size = UIScreen.mainScreen().bounds.size
        loader = UIView(frame: CGRectMake(0, 0, size.width, size.height))
        loader?.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.6)
        navigationController?.view.addSubview(loader!)
        
        let activityIndicatorView = UIActivityIndicatorView()
        loader?.addSubview(activityIndicatorView)
        activityIndicatorView.center = loader!.center
        activityIndicatorView.startAnimating()
        
        MessagingToken.getToken(Static.host) { (error, headers) -> Void in
            if error != nil {
                self.error(error!)
            } else {
                if headers != nil {
                    self.headers = headers!
                }
                if self.appearing {
                    self.connect()
                }
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        appearing = false
    }
    
    func removeLoader() {
        if let view: UIView = loader {
            view.hidden = true
            view.removeFromSuperview()
            loader = nil
        }
    }

    func error(message: String) {
        removeLoader()
        
        let alert = UIAlertView(
            title: "Error",
            message: message,
            delegate: nil,
            cancelButtonTitle: "Ok")
        alert.show()
    }
    
}
