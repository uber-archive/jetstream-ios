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
    let longPollListenPort: Int
    let longPollTransport: LongPollChunkedSocketServer
    let mqttClient: MQTTClient
    
    init(options: MQTTLongPollChunkedConnectionOptions) {
        self.options = options as ConnectionOptions
        
        // TODO: find open port instead of constant port
        longPollListenPort = 8888
        longPollTransport = LongPollChunkedSocketServer(options: options, port: longPollListenPort)
        
        var uuid = UIDevice.currentDevice().identifierForVendor.UUIDString
        mqttClient = MQTTClient(clientId: "mqttios_\(uuid)", cleanSession: true)
        mqttClient.port = UInt16(longPollListenPort)
        // TODO: read ping from connection options
        mqttClient.keepAlive = 5
        mqttClient.messageHandler = { [unowned self] (message) in
            self.mqttMessageReceived(message)
        }
        mqttClient.disconnectionHandler = { [unowned self] (code) in
            self.status = .Connecting
        }
    }
    
    func connect() {
        status = .Connecting
        mqttClient.connectToHost("localhost") { [unowned self] (code) in
            if code.value == ConnectionAccepted.value {
                self.status = .Connected
                self.mqttSetupSubscriptions()
            } else {
                self.status = .Connecting
            }
        }
    }
    
    func sendMessage(message: Message) {
        
    }
    
    private func mqttSetupSubscriptions() {
        mqttClient.subscribe("/sync/\(mqttClient.clientID)", withQos: AtLeastOnce, completionHandler: nil)
    }
    
    private func mqttMessageReceived(message: MQTTMessage) {
        logger.debug("Received MQTTMessage \(message.payloadString())")
    }
    
}

class LongPollChunkedSocketServer {
    
    let logger = Logging.loggerFor("LongPollChunkedSocketServer")
    
    var openClients = [Int32:LongPollChunkedSocketServerClient]()
    
    let socket: PassiveSocket<sockaddr_in>
    let lockQueue = dispatch_queue_create("com.uber.jetstream.lpcsocketserver", nil)!
    let options: MQTTLongPollChunkedConnectionOptions
    let port: Int
    
    init(options: MQTTLongPollChunkedConnectionOptions, port: Int) {
        self.options = options
        self.port = port
        let address = sockaddr_in(port: port)
        socket = PassiveSocket<sockaddr_in>(address: address)
        socket.listen(
            dispatch_get_global_queue(0, 0),
            backlog: 5,
            accept: { [unowned self] (sock: ActiveSocket<sockaddr_in>) in
            
            self.accept(sock)
        })
    }
    
    private func accept(sock: ActiveSocket<sockaddr_in>) {
        logger.debug("ACCEPTED (port=\(port))")
        
        sock.isNonBlocking = true
        
        var client = LongPollChunkedSocketServerClient(socket: sock, options: options)
        
        dispatch_async(self.lockQueue) {
            // Note: we need to keep the socket around!
            self.openClients[sock.fd!] = client
        }
        
        sock.onClose { [unowned self] (fd: Int32) in
            dispatch_async(self.lockQueue) { [unowned self] in
                self.logger.debug("CLOSE (fd=\(fd))")
                _ = self.openClients.removeValueForKey(fd)
            }
        }
    }
    
}

class LongPollChunkedSocketServerClient: NSObject, NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate {
    
    let logger = Logging.loggerFor("LongPollChunkedSocketServerClient")
    let options: MQTTLongPollChunkedConnectionOptions
    let socket: ActiveSocket<sockaddr_in>
    let queue: NSOperationQueue
    let streamQueue: NSOperationQueue
    let postQueue: NSOperationQueue

    // Lock queue is for operating on `buffer` and `sending`
    let lockQueue: dispatch_queue_t

    var headers = [String:String]()
    var buffer = [CChar]()
    var sending = false
    var dead = false
    var sendId: String?
    var pendingFirstByte = true
    var session: NSURLSession?
    
    init(socket: ActiveSocket<sockaddr_in>, options: MQTTLongPollChunkedConnectionOptions) {
        let queuePrefixName = "com.uber.jetstream.lpcsocketserverclient.\(socket.fd!)"
        self.socket = socket
        self.options = options
        queue = NSOperationQueue()
        queue.name = "\(queuePrefixName).outbound"
        queue.maxConcurrentOperationCount = 1
        
        postQueue = NSOperationQueue()
        postQueue.name = "\(queuePrefixName).outbound.post"
        
        streamQueue = NSOperationQueue()
        streamQueue.name = "\(queuePrefixName).inbound"
        streamQueue.maxConcurrentOperationCount = 1
        
        lockQueue = dispatch_queue_create("\(queuePrefixName).lock", nil)

        if options.headers.count > 0 {
            for (key, value) in options.headers {
                headers[key] = value
            }
        }
        
        if headers["Content-Type"] == nil && headers["content-type"] == nil {
            headers["Content-Type"] = "application/octet-stream"
        }
        
        super.init()
        
        streamOutgoingPrepare()
        streamOutgoingData()
        socket.onRead { [unowned self] (_, expected) in
            self.handleIncomingData(expected)
        }
    }
    
    /// MARK: Receive chunked data from server for MQTT client
    
    func streamOutgoingPrepare() {
        pendingFirstByte = true
    }
    
    func streamOutgoingData() {
        var request = NSMutableURLRequest(URL: NSURL(string: options.receiveURL))
        request.HTTPMethod = "POST"
        
        if headers.count > 0 {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        logger.debug("SEND (request=\(request)")
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        session = NSURLSession(configuration: config, delegate: self, delegateQueue: streamQueue)
        var task = session?.dataTaskWithRequest(request)
        task?.resume()
    }
    
    /// MARK: NSURLSessionDelegate
    
    func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
        cleanup()
    }
    
    /// MARK: NSURLSessionDataDelegate
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        if dead {
            return cleanup()
        }
        
        var sendIdWasNil = sendId == nil
        
        if let httpResponse = response as? NSHTTPURLResponse {
            for (name, value) in httpResponse.allHeaderFields {
                var headerName = name as? NSString
                var headerValue = value as? NSString
                var headerNameString = headerName?.lowercaseString
                var headerValueString = headerValue?.lowercaseString
                
                if headerNameString != nil && headerValueString != nil {
                    if headerNameString?.hasSuffix("sendid") == true {
                        let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
                        sendId = headerValueString?.stringByTrimmingCharactersInSet(whitespace)
                        headers[headerName!] = sendId!
                    }
                }
            }
        }
        
        if options.sendIdRequired && sendId != nil && sendIdWasNil {
            // Send any buffered data
            if sendId != nil {
                logger.debug("GOTSENDID (sendId=\(sendId)")
                queueBufferedSend()
            }
        }
        
        completionHandler(.Allow)
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if dead {
            return cleanup()
        }
        
        logger.debug("GOTDATA (data.length=\(data.length))")
        
        var received = data
        
        if pendingFirstByte && received.length > 0 {
            let str: String = NSString(
                data: received.subdataWithRange(NSMakeRange(0, 1)),
                encoding: NSUTF8StringEncoding)
            
            if str == "0" {
                received = received.subdataWithRange(NSMakeRange(1, received.length - 1))
                pendingFirstByte = false
            } else {
                return cleanup()
            }
        }

        if received.length > 0 {
            if socket.canWrite {
                logger.debug("WRITEDATA (data.length=\(data.length))")
                socket.write(received)
            } else {
                logger.debug("CANNOTWRITEDATA (data.length=\(data.length))")
            }
        }
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        logger.debug("GOTEND")
        cleanup()
    }
    
    /// MARK: Send data to server on behalf of MQTT client
    
    func handleIncomingData(expectedIncomingDataCount: Int) {
        do {
            if dead {
                return cleanup()
            }
        
            let (count, block, err) = socket.read()
            
            if count < 0 && err == EWOULDBLOCK {
                break
            }
        
            if count < 1 {
                logger.debug("EOF (socket=\(socket)) (err=\(err))")
                return cleanup()
            }
            
            dispatch_async(self.lockQueue) { [unowned self] in
                for i in 0 ..< count {
                    self.buffer.append(block[i])
                }
            }
            
            logger.debug("RECV block (length=\(count))")
        } while (true)

        // Delay 1msec to ensure fully buffered from any run loops
        delay(0.001) { [unowned self] in
            self.queueBufferedSend()
        }
    }
    
    func queueBufferedSend() {
        queue.addOperationWithBlock() { [unowned self] in
            self.sendBufferedData()
        }
    }
    
    func sendBufferedData() {
        if dead {
            return cleanup()
        }
        
        var shouldSend = true
        
        // Note: this happens on background queue so safe to synchronously lock on lockQueue
        dispatch_sync(self.lockQueue) {
            var alreadySending = self.sending
            shouldSend = !alreadySending
            if self.options.sendIdRequired && self.sendId == nil {
                // Wait to receive the send ID
                shouldSend = false
            }
            if shouldSend {
                self.sending = true
            }
        }
        
        if !shouldSend {
            // When sending is finished or we receive send ID we will start another send
            return
        }

        // Get the buffer and replace with a new one
        var data: [CChar]?
        
        dispatch_sync(self.lockQueue) {
            if self.buffer.count > 0 {
                data = self.buffer
                self.buffer = [CChar]()
            }
        }
        
        // Nothing to send
        if data == nil || data?.count < 1 {
            return
        }
        
        var request = NSMutableURLRequest(URL: NSURL(string: options.sendURL))
        request.HTTPMethod = "POST"
        request.HTTPBody = NSData(bytes: data!, length: data!.count)
        
        if headers.count > 0 {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        logger.debug("POST (request=\(request)")
        NSURLConnection.sendAsynchronousRequest(request, queue: postQueue) {
            [unowned self] (response, data, error) in
            if self.dead {
                return self.cleanup()
            }
            
            // Something in the connection died, make MQTT 
            // reconnect and resend as if a new connection started
            if error != nil {
                return self.cleanup()
            }
            
            if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return self.cleanup()
                } else {
                    self.logger.debug("SENTDATA (data.length=\(request.HTTPBody?.length)")
                }
            } else {
                return self.cleanup()
            }
            
            dispatch_async(self.lockQueue) { [unowned self] in
                self.sending = false
                
                // If things got buffered and we denied sending as
                // we were performing this send, start another send
                if self.buffer.count > 0 {
                    self.queueBufferedSend()
                }
            }
        }
    }
    
    func cleanup() {
        dispatch_sync(self.lockQueue) {
            if !self.dead {
                self.logger.debug("CLOSE (socket=\(self.socket))")
                self.dead = true
                self.socket.close()
            }
        }
    }
    
}
