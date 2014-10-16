//
//  WebSocketTransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 10/12/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals
import Starscream
import SystemConfiguration

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

class WebsocketTransportAdapter: NSObject, TransportAdapter, WebsocketDelegate {
    struct Static {
        static let className = "WebsocketTransportAdapter"
        static let inactivityPingIntervalSeconds: NSTimeInterval = 10
        static let inactivityPingIntervalVarianceSeconds: NSTimeInterval = 2
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
    let url: NSURL
    let socket: Websocket
    var explicitlyClosed = false
    var session: Session?
    var pingTimer: NSTimer?
    var nonAckedSends = [Message]()
    
    init(options: ConnectionOptions, headers: [String: String]) {
        self.options = options
        self.url = NSURL.URLWithString(options.url)
        socket = Websocket(url: url)
        super.init()
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
        tryConnect()
    }
    
    func tryConnect() {
        if status != .Connecting {
            return
        }
        
        if canReachHost() {
            socket.connect()
        } else {
            delay(0.1) {
                self.tryConnect()
            }
        }
    }
    
    func disconnect() {
        if status == .Closed {
            return
        }
        explicitlyClosed = true
        session = nil
        stopPingTimer()
        socket.disconnect()
    }
    
    func reconnect() {
        if status != .Connected {
            return
        }
        stopPingTimer()
        socket.disconnect()
    }
    
    func sendMessage(message: Message) {
        if session != nil {
            nonAckedSends.append(message)
        }
        transportMessage(message)
    }
    
    func transportMessage(message: Message) {
        if status != .Connected {
            return
        }
        
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
    
    func sessionEstablished(session: Session) {
        self.session = session
        socket.headers["X-Jetstream-SessionToken"] = session.token
        startPingTimer()
    }
    
    func startPingTimer() {
        stopPingTimer()
        var varianceLowerBound = Static.inactivityPingIntervalSeconds - (Static.inactivityPingIntervalVarianceSeconds / 2)
        var randomVariance = Double(arc4random_uniform(UInt32(Static.inactivityPingIntervalVarianceSeconds)))
        var delay = varianceLowerBound + randomVariance
        
        pingTimer = NSTimer.scheduledTimerWithTimeInterval(
            delay,
            target: self,
            selector: Selector("pingTimerFired"),
            userInfo: nil,
            repeats: false)
    }
    
    func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    func pingTimerFired() {
        sendMessage(PingMessage(session: session!))
        startPingTimer()
    }
    
    func pingMessageReceived(pingMessage: PingMessage) {
        nonAckedSends = nonAckedSends.filter { $0.index > pingMessage.ack }
        
        if pingMessage.resendMissing {
            for message in nonAckedSends {
                transportMessage(message)
            }
        }
    }
    
    func websocketDidConnect() {
        status = .Connected
        if session != nil {
            // Request missed messages
            sendMessage(PingMessage(session: session!, resendMissing: true))
            // Restart the ping timer lost after disconnecting
            startPingTimer()
        }
    }
    
    func websocketDidDisconnect(error: NSError?) {
        // Starscream sometimes dispatches this on another thread
        dispatch_async(dispatch_get_main_queue()) {
            self.didDisconnect()
        }
    }
    
    func didDisconnect() {
        stopPingTimer()
        if status == TransportStatus.Connecting {
            status = .Closed
        }
        if !explicitlyClosed {
            connect()
        }
    }
    
    func websocketDidWriteError(error: NSError?) {
        if error != nil {
            logger.error("socket error: \(error!.localizedDescription)")
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
                switch message! {
                case let pingMessage as PingMessage:
                    pingMessageReceived(pingMessage)
                default:
                    break
                }
                onMessage.fire(message!)
            }
        }
    }
    
    func websocketDidReceiveData(data: NSData) {
        logger.debug("received data (len=\(data.length)")
    }
    
    func canReachHost() -> Bool {
        var hostAddress = sockaddr_in(
            sin_len: 0,
            sin_family: 0,
            sin_port: 0,
            sin_addr: in_addr(s_addr: 0),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        hostAddress.sin_len = UInt8(sizeofValue(hostAddress))
        hostAddress.sin_family = sa_family_t(AF_INET)
        hostAddress.sin_port = UInt16(UInt(url.port!))
        inet_pton(AF_INET, url.host!, &hostAddress.sin_addr)
        
        let defaultRouteReachability = withUnsafePointer(&hostAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        var isReachable: Bool = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        var needsConnection: Bool = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        var transientConnection: Bool = (flags & UInt32(kSCNetworkFlagsTransientConnection)) != 0
        var connectionAutomatic: Bool = (flags & UInt32(kSCNetworkFlagsConnectionAutomatic)) != 0
        var interventionRequired: Bool = (flags & UInt32(kSCNetworkFlagsInterventionRequired)) != 0
        var isLocalAddress: Bool = (flags & UInt32(kSCNetworkFlagsIsLocalAddress)) != 0
        var isDirect: Bool = (flags & UInt32(kSCNetworkFlagsIsDirect)) != 0
        
        return isReachable && !needsConnection && !transientConnection
    }
}
