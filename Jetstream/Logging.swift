//
//  Logger.swift
//  Jetstream
//
//  Created by Rob Skillington on 9/24/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import Foundation

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
        return Swell.getLogger(loggerName)
    }
    
    public class func disable() {
        Swell.disableLogging()
    }
    
}
