//
//  Client.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

public enum ClientStatus {
    case Offline
    case Online
}

public class Client {
    
    public let onStatusChanged = Signal<(ClientStatus)>()
    public let onSession = Signal<(Session)>()
    
    var __status: ClientStatus = .Offline
    var _status: ClientStatus {
        get {
            return __status
        }
        set {
            onStatusChanged.fire(newValue)
            __status = newValue
        }
    }
    public var status: ClientStatus {
        get {
            return _status
        }
    }
    
    var _session: Session?
    public var session: Session? {
        get {
            return _session
        }
    }
    
    private let transport: Transport
    
    public init(options: ConnectionOptions) {
        var defaultAdapter = Transport.defaultTransportAdapter(options)
        transport = Transport(adapter: defaultAdapter)
        transport.onStatusChanged.listen(self, callback: { (status: TransportStatus) -> Void in
            switch status {
            case .Closed:
                self._status = .Offline
            case .Connecting:
                self._status = .Offline
            case .Connected:
                self._status = .Online
            }
        })
    }
    
    public func connect() {
        transport.connect()
    }
    
    public func close() {
        // Close up any resources
    }
    
    public func removeListener(listener: AnyObject) {
        self.onStatusChanged.removeListener(listener)
        self.onSession.removeListener(listener)
    }

}
