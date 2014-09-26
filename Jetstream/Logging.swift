//
//  Logger.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

let disabledLoggers = [
    "LongPollChunkedSocketServerClient": true,
    "LongPollChunkedSocketServer": true
]

public class Logging {
    
    class var loggerName: String {
        get {
            let name = "Jetstream"
            return name
        }
    }
    
    class var logger: Logger {
        get {
            return Swell.getLogger(Logging.loggerName)
        }
    }
    
    class func loggerFor(str: String) -> Logger {
        var loggerName = "\(Logging.loggerName).\(str)"
        var logger = Swell.getLogger(loggerName)
        if disabledLoggers[str] == true {
            logger.enabled = false
        }
        return logger
    }
    
    public class func disable() {
        Swell.disableLogging()
    }
    
}
