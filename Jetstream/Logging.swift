//
//  Logger.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Signals

let disabledLoggers = [String: Bool]()

public class Logging {
    struct Static {
        static let baseLoggerName = "Jetstream"
        static var enabled = false
        static var consoleEnabled = true
        static var loggers = [String: Logger]()
        static let onMessage = Signal<(level: String, message: String)>()
    }
    
    class var logger: Logger {
        get {
            if let logger = Static.loggers[Static.baseLoggerName] {
                return logger
            }
            let logger = Logger(name: Static.baseLoggerName)
            Static.loggers[Static.baseLoggerName] = logger
            return logger
        }
    }
    
    class func loggerFor(str: String) -> Logger {
        let loggerName = "\(Static.baseLoggerName).\(str)"

        var logger = Static.loggers[loggerName]
        if logger == nil {
            logger = Logger(name: loggerName)
            Static.loggers[loggerName] = logger
        }
        if disabledLoggers[str] == true {
            logger!.enabled = false
        }
        return logger!
    }
    
    public class var onMessage: Signal<(level: String, message: String)> {
        get {
            return Static.onMessage
        }
    }
    
    public class func enableAll() {
        Static.enabled = true
    }
    
    public class func disableAll() {
        Static.enabled = false
    }
    
    public class func enableConsole() {
        Static.enabled = true
        Static.consoleEnabled = true
    }
    
    public class func disableConsole() {
        Static.consoleEnabled = false
    }
}

class Logger {
    let name: String
    var enabled: Bool

    init(name: String, enabled: Bool) {
        self.name = name
        self.enabled = enabled
    }
    
    convenience init(name: String) {
        self.init(name: name, enabled: true)
    }
    
    func trace<T: Printable>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log("TRACE", message: message)
    }
    
    func debug<T: Printable>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log("DEBUG", message: message)
    }
    
    func info<T: Printable>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log("INFO", message: message)
    }
    
    func warn<T: Printable>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log("WARN", message: message)
    }
    
    func error<T: Printable>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log("ERROR", message: message)
    }
    
    func log<T: Printable>(level: String, message: T) {
        let str = "\(name): \(message)"
        if Logging.Static.consoleEnabled {
            println("\(level) \(str)")
        }

        Logging.Static.onMessage.fire((level: level, message: str))
    }
}
