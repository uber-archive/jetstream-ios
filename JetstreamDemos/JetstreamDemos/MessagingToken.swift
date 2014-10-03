//
//  MessagingToken.swift
//  JetstreamDemos
//
//  Created by Rob Skillington on 10/3/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import Foundation

class MessagingToken {
    
    class func getToken(host: String, withCallback: (String?, [String: String]?) -> Void) {
        var request = NSMutableURLRequest(URL: NSURL(string: "http://" + host + ":3000/mqtt/register"))
        request.HTTPMethod = "POST"
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { (response, data, error) in
            if error != nil {
                withCallback("Could not parse registration", nil)
                return
            }
            
            var jsonError: NSError?
            let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError)
            if let registration = json as? Dictionary<String, AnyObject> {
                let maybeToken: AnyObject? = registration["token"]
                if let token = maybeToken as? String {
                    var headers = [String: String]()
                    headers["X-Uber-Messaging-Token"] = token
                    withCallback(nil, headers)
                    return
                } else {
                    withCallback("Could not parse token from registration", nil)
                    return
                }
            } else {
                withCallback("Could not parse registration", nil)
                return
            }
        }
    }
    
}
