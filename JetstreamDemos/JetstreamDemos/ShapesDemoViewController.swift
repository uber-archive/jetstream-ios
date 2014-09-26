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
    
    var headers = [String:String]()
    var client: Client?
    var session: Session?
    var appearing = false
    var scope = Scope(name: "Kiva")
    var shapesDemoModel = ShapesDemoModel()
    
    override func viewDidLoad() {
        title = "Shapes Demo"
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleTap:"))
        self.view.addGestureRecognizer(tapRecognizer)
        
        
        shapesDemoModel.setScopeAndMakeRootModel(scope)
        
        shapesDemoModel.observeCollectionAdd(self, keyPath: "shapes") { (element: Shape) -> Void in
            let shapeView = ShapeView(shape: element)
            self.view.addSubview(shapeView)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        appearing = true
        return
        
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
    
    func error(message: String) {
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
            NSLog("Got session with token: %@", session.token)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        appearing = false
    }
    
    override func viewDidDisappear(animated: Bool) {
        client?.onSession.removeListener(self)
        client?.close()
        client = nil
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        let shape = Shape()
        var point = recognizer.locationInView(self.view)
        shape.x = point.x - shape.width / 2
        shape.y = point.y - shape.height / 2
        shapesDemoModel.shapes.append(shape)
    }
    
}
