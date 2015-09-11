//
//  Logging.swift
//  Jetstream
//
//  Copyright (c) 2014 Uber Technologies, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

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
    
    public class func loggerFor(str: String) -> Logger {
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

public class Logger {
    let name: String
    var enabled: Bool

    init(name: String, enabled: Bool) {
        self.name = name
        self.enabled = enabled
    }
    
    convenience init(name: String) {
        self.init(name: name, enabled: true)
    }
    
    public func trace<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Trace, message: message)
    }

    public func debug<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Debug, message: message)
    }

    public func info<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Info, message: message)
    }

    public func warn<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Warning, message: message)
    }
    
    public func error<T>(message: T) {
        if !Logging.Static.enabled || !enabled {
            return
        }
        log(.Error, message: message)
    }
    
    func log<T>(level: LogLevel, message: T) {
        let str = "\(name): \(message)"
        if Logging.Static.consoleEnabled {
            print("\(level) \(str)")
        }

        Logging.Static.onMessage.fire((level: level, message: str))
    }
}
