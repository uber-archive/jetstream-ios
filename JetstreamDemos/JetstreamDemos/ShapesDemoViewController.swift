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
    
    var shapesDemo = ShapesDemo()
    var scope = Scope(name: "ShapesDemo")
    
    var headers = [String:String]()
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
    
    override func viewWillAppear(animated: Bool) {
        appearing = true
        
        var size = UIScreen.mainScreen().bounds.size
        loader = UIView(frame: CGRectMake(0, 0, size.width, size.height))
        loader?.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.6)
        navigationController?.view.addSubview(loader!)
        
        let activityIndicatorView = UIActivityIndicatorView()
        loader?.addSubview(activityIndicatorView)
        activityIndicatorView.center = loader!.center
        activityIndicatorView.startAnimating()

        var request = NSMutableURLRequest(URL: NSURL(string: "http://localhost:3000/mqtt/register"))
        request.HTTPMethod = "POST"
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
            [unowned self] (response, data, error) in
            if error != nil {
                return self.error("Could not register, error=\(error)")
            }

            var jsonError: NSError?
            let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError)
            if let registration = json as? Dictionary<String, AnyObject> {
                let maybeToken: AnyObject? = registration["token"]
                if let token = maybeToken as? String {
                    self.headers["X-Uber-Messaging-Token"] = token
                    if self.appearing {
                        self.connect()
                    }
                } else {
                    return self.error("Could not parse token from registration")
                }
            } else {
                return self.error("Could not parse registration")
            }
        }
    }
    
    func removeLoader() {
        if loader != nil {
            loader?.removeFromSuperview()
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
    
    func connect() {
        client = Client(options: MQTTLongPollChunkedConnectionOptions(
            receiveURL: "http://localhost:3000/mqtt/lpc/connect",
            sendURL: "http://localhost:3000/mqtt/lpc/send",
            headers: headers,
            sendIdRequired: true))
        client?.connect()
        client?.onSession.listenOnce(self) { [unowned self] (session) in
            self.session = session
            let scope = self.scope
            session.fetch(scope) { [unowned self] (maybeError) in
                if maybeError != nil {
                    NSLog("Request scope error: %@", maybeError!)
                } else {
                    NSLog("Retrieved scope")
                    self.removeLoader()
                }
            }
            NSLog("Got session with token: %@", session.token)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        appearing = false
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
    
}
