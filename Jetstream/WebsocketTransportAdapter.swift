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

/// A set of connection options.
public struct WebsocketConnectionOptions: ConnectionOptions {
    
    /// Headers to connect with
    public var url: NSURL
    
    /// A dictionary of key-value pairs to send as headers when connecting.
    public var headers: [String: String]
    
    public init(url: NSURL, headers: [String: String] = [String: String]()) {
        self.url = url
        self.headers = headers
    }
}

/// A transport adapter that connects to the the jetstream service via a persistent Websocket.
public class WebsocketTransportAdapter: NSObject, TransportAdapter, WebsocketDelegate {
    struct Static {
        static let className = "WebsocketTransportAdapter"
        static let inactivityPingIntervalSeconds: NSTimeInterval = 10
        static let inactivityPingIntervalVarianceSeconds: NSTimeInterval = 2
    }
    
    public let onStatusChanged = Signal<(TransportStatus)>()
    public let onMessage = Signal<(Message)>()
    public let adapterName = Static.className
    public let options: ConnectionOptions
    
    public internal(set) var status: TransportStatus = .Closed {
        didSet {
            onStatusChanged.fire(status)
        }
    }
    
    let logger = Logging.loggerFor(Static.className)
    let url: NSURL
    let socket: Websocket
    var explicitlyClosed = false
    var session: Session?
    var pingTimer: NSTimer?
    var nonAckedSends = [Message]()

    /// Constructor.
    ///
    /// :param: options Options to connect to the service with.
    public init(options: WebsocketConnectionOptions ) {
        self.options = options
        self.url = options.url
        socket = Websocket(url: url)
        super.init()
        socket.delegate = self
        for (key, value) in options.headers {
            socket.headers[key] = value
        }
    }
    
    // MARK: - TransportAdapter
    public func connect() {
        if status == TransportStatus.Connecting {
            return
        }
        status = .Connecting
        tryConnect()
    }
    
    public func disconnect() {
        if status == .Closed {
            return
        }
        explicitlyClosed = true
        session = nil
        stopPingTimer()
        socket.disconnect()
    }
    
    public func reconnect() {
        if status != .Connected {
            return
        }
        stopPingTimer()
        socket.disconnect()
    }
    
    public func sendMessage(message: Message) {
        if session != nil {
            nonAckedSends.append(message)
        }
        transportMessage(message)
    }
    
    public func sessionEstablished(session: Session) {
        self.session = session
        socket.headers["X-Jetstream-SessionToken"] = session.token
        startPingTimer()
    }
    
    // MARK: - WebsocketDelegate
    public func websocketDidConnect() {
        status = .Connected
        if session != nil {
            // Request missed messages
            sendMessage(PingMessage(session: session!, resendMissing: true))
            // Restart the ping timer lost after disconnecting
            startPingTimer()
        }
    }
    
    public func websocketDidDisconnect(error: NSError?) {
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
    
    public func websocketDidWriteError(error: NSError?) {
        if error != nil {
            logger.error("socket error: \(error!.localizedDescription)")
        }
    }
    
    public func websocketDidReceiveMessage(str: String) {
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
    
    public func websocketDidReceiveData(data: NSData) {
        logger.debug("received data (len=\(data.length)")
    }
    
    // MARK: - Interal Interface
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
        
        if let definiteJSON = json {
            if let str = NSString(data: definiteJSON, encoding: NSUTF8StringEncoding) {
                socket.writeString(str)
                logger.debug("sent: \(str)")
            }
        }
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
