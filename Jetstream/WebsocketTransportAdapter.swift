//
//  WebSocketTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/12/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation
import Signals
import Starscream

public class WebsocketConnectionOptions: ConnectionOptions {
    public let headers: [String: String]
    
    public init(url: String, headers: [String: String]) {
        self.headers = headers
        super.init(url: url)
    }
    
    override convenience public init(url: String) {
        self.init(url: url, headers: [String: String]())
    }
}

class WebsocketTransportAdapter: TransportAdapter, WebsocketDelegate {
    struct Static {
        static let className = "WebsocketTransportAdapter"
    }
    
    let logger = Logging.loggerFor(Static.className)
    
    let onStatusChanged = Signal<(TransportStatus)>()
    let onMessage = Signal<(Message)>()
    
    let adapterName = Static.className
    
    var status: TransportStatus = .Closed {
        didSet {
            onStatusChanged.fire(status)
        }
    }
    
    let options: ConnectionOptions
    let socket: Websocket
    var explicitlyClosed = false
    
    init(options: ConnectionOptions, headers: [String: String]) {
        self.options = options
        socket = Websocket(url: NSURL.URLWithString(options.url))
        socket.delegate = self
        for (key, value) in headers {
            socket.headers[key] = value
        }
    }
    
    convenience init(options: ConnectionOptions) {
        self.init(options: options, headers: [String: String]())
    }
    
    convenience init(options: WebsocketConnectionOptions) {
        self.init(options: options, headers: options.headers)
    }
    
    func connect() {
        if status == TransportStatus.Connecting {
            return
        }
        status = .Connecting
        socket.connect()
    }
    
    func disconnect() {
        if status == .Closed {
            return
        }
        explicitlyClosed = true
        socket.disconnect()
    }
    
    func sendMessage(message: Message) {
        let dictionary = message.serialize()
        let error = NSErrorPointer()
        let json = NSJSONSerialization.dataWithJSONObject(
            dictionary,
            options: NSJSONWritingOptions(0),
            error: error)
        
        if json != nil {
            let str = NSString(data: json!, encoding: NSUTF8StringEncoding)
            socket.writeString(str)
            logger.debug("sent: \(str)")
        }
    }
    
    func websocketDidConnect() {
        status = .Connected
    }
    
    func websocketDidDisconnect(error: NSError?) {
        if status == TransportStatus.Connecting {
            status = .Closed
        }
        if !explicitlyClosed {
            connect()
        }
    }
    
    func websocketDidWriteError(error: NSError?) {
        if error != nil {
            logger.error("Error: " + error!.localizedDescription)
        }
    }
    
    func websocketDidReceiveMessage(str: String) {
        logger.debug("received: \(str)")
        
        let data = str.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        
        if data != nil {
            let error = NSErrorPointer()
            let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(
                data!,
                options: NSJSONReadingOptions(0),
                error: error)
            
            if json != nil {
                if let array = json as? [AnyObject] {
                    for object in array {
                        tryReadSerializedMessage(object)
                    }
                } else {
                    tryReadSerializedMessage(json!)
                }
            }
        }
    }
    
    private func tryReadSerializedMessage(object: AnyObject) {
        if let dictionary = object as? [String: AnyObject] {
            let message = Message.unserialize(dictionary)
            if message != nil {
                onMessage.fire(message!)
            }
        }
    }
    
    
    func websocketDidReceiveData(data: NSData) {
        logger.debug("received data (len=\(data.length)")
    }
}
