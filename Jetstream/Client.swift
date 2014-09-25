//
//  Client.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

public enum ClientStatus {
    case Offline
    case Online
}

public class Client {
    
    /// MARK: Events
    
    public let onStatusChanged = Signal<(ClientStatus)>()
    public let onSession = Signal<(Session)>()

    /// MARK: Properties
    
    public private(set) var status: ClientStatus = .Offline {
        didSet {
            onStatusChanged.fire(status)
        }
    }
    
    public private(set) var session: Session?
    
    let transport: Transport
    
    /// MARK: Public interface
    
    public init(options: ConnectionOptions) {
        var defaultAdapter = Transport.defaultTransportAdapter(options)
        transport = Transport(adapter: defaultAdapter)
        bindListeners()
    }
    
    public func connect() {
        transport.connect()
    }
    
    public func close() {
        // Close up any resources
    }
    
    /// MARK: Private interface
    
    private func bindListeners() {
        onStatusChanged.listen(self) { (status) in
            switch status {
            case .Online:
                if self.session == nil {
                    self.createSession()
                } else {
                    self.resumeSession()
                }
            default:
                return
            }
        }
        transport.onStatusChanged.listen(self) { (status: TransportStatus) in
            switch status {
            case .Closed:
                self.status = .Offline
            case .Connecting:
                self.status = .Offline
            case .Connected:
                self.status = .Online
            }
        }
        transport.onMessage.listen(self) { (message: Message) in
            // TODO: implement
        }
    }
    
    private func createSession() {
        transport.sendMessage(SessionCreateMessage())
    }
    
    private func resumeSession() {
        // TODO: implement
    }

}
