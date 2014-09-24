//
//  TransportAdapter.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

protocol TransportAdapter {
    
    var onStatusChanged: Signal<(TransportStatus)> { get }
    var onMessage: Signal<(Message)> { get }
    
    var status: TransportStatus { get }

    func connect()
    func sendMessage(message: Message)
    
}
