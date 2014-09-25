//
//  MQTTLongPollChunkedTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

class MQTTLongPollChunkedTransportAdapter: TransportAdapter {
    
    private struct Static {
        static let className = "MQTTLongPollChunkedTransportAdapter"
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
    let mqttClient: MQTTClient
    
    init(options: ConnectionOptions) {
        self.options = options
        var uuid = UIDevice.currentDevice().identifierForVendor.UUIDString
        mqttClient = MQTTClient(clientId: "mqttios_mqttkit_\(uuid)")
    }
    
    func connect() {
        status = .Connecting
    }
    
    func sendMessage(message: Message) {
        
    }
    
}

class LongPollChunkedSocketServer {
    
    private var openClients = [Int32:LongPollChunkedSocketServerClient]()
    
    private let socket: PassiveSocket<sockaddr_in>
    private let lockQueue = dispatch_queue_create("com.uber.jetstream.lpcsocketserver", nil)!
    private let options: ConnectionOptions
    
    init(options: ConnectionOptions) {
        self.options = options
        let address = sockaddr_in(port: 8888)
        socket = PassiveSocket<sockaddr_in>(address: address)
        socket.listen(
            dispatch_get_global_queue(0, 0),
            backlog: 5,
            accept: { [unowned self] (sock: ActiveSocket<sockaddr_in>) in
            
            self.accept(sock)
        })
    }
    
    private func accept(sock: ActiveSocket<sockaddr_in>) {
        sock.isNonBlocking = true
        
        var client = LongPollChunkedSocketServerClient(socket: sock)
        
        dispatch_async(self.lockQueue) {
            // Note: we need to keep the socket around!
            self.openClients[sock.fd!] = client
        }
        
        sock.onClose { [unowned self] (fd: Int32) -> Void in
            dispatch_async(self.lockQueue) { [unowned self] in
                _ = self.openClients.removeValueForKey(fd)
            }
        }
    }
    
}

class LongPollChunkedSocketServerClient {
    
    let socket: ActiveSocket<sockaddr_in>
    
    init(socket: ActiveSocket<sockaddr_in>) {
        self.socket = socket
    }
    
}
