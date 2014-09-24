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

class ShapesDemoViewController: UIViewController {
    
    var client: Client?
    var session: Session?
    
    override func viewDidLoad() {
        title = "Shapes Demo"
    }
    
    override func viewWillAppear(animated: Bool) {
        client = Client(options: ConnectionOptions(url: "http://localhost:3000"))
        client?.connect()
        client?.onSession.listenOnce(self, callback: { (session) -> Void in
            self.session = session
            NSLog("Got session with token: %@", session.token)
        })
    }
    
    override func viewDidDisappear(animated: Bool) {
        client?.removeListener(self)
        client?.close()
        client = nil
    }
    
}
