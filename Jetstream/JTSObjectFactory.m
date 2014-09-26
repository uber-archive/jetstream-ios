//
//  JTSObjectFactory.m
//  Jetstream
//
//  Created by Tuomas Artman on 9/25/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

#import "JTSObjectFactory.h"

@implementation JTSObjectFactory

+ (id)create:(NSString *)className
{
    return [NSClassFromString(className) new];
}

@end
