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

public enum LogLevel: String {
    case Trace = "TRACE"
    case Debug = "DEBUG"
    case Info = "INFO"
    case Warning = "WARN"
    case Error = "ERROR"
}

/// Jetstreams logging class. To subscribe to logging events from Jetstream, subscribe to the
/// Logging.onMessage - signal.
public class Logging {
    struct Static {
        static let baseLoggerName = "Jetstream"
        static var enabled = false
        static var consoleEnabled = true
        static var loggers = [String: Logger]()
        static let onMessage = Signal<(level: LogLevel, message: String)>()
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
    
    /// A signal that is fired whenever Jetstream logs. The signal fires with the parameters LogLevel
    /// and Message.
    public class var onMessage: Signal<(level: LogLevel, message: String)> {
        get {
            return Static.onMessage
        }
    }
    
    /// Enables all logging.
    public class func enableAll() {
        Static.enabled = true
    }
    
    /// Disables all logging.
    public class func disableAll() {
        Static.enabled = false
    }
    
    /// Enables logging to the console.
    public class func enableConsole() {
        Static.enabled = true
        Static.consoleEnabled = true
    }
    
    /// Disables logging to the console
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
    
    func trace<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Trace, message: message)
    }
    
    func debug<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Debug, message: message)
    }
    
    func info<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Info, message: message)
    }
    
    func warn<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Warning, message: message)
    }
    
    func error<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Error, message: message)
    }
    
    func log<T>(level: LogLevel, message: T) {
        let str = "\(name): \(message)"
        if Logging.Static.consoleEnabled {
            println("\(level) \(str)")
        }

        Logging.Static.onMessage.fire((level: level, message: str))
    }
}
