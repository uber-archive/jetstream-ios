//
//  JTSObjectFactory.h
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JTSObjectFactory : NSObject

+ (id)create:(NSString *)className;

@end
