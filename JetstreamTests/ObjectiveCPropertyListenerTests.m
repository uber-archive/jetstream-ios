//
//  ObjectiveCTests.m
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

#import <XCTest/XCTest.h>
#import <JetstreamTests-Swift.h>

@interface ObjectiveCPropertyListenerTests : XCTestCase
@end

@implementation ObjectiveCPropertyListenerTests

- (void)testSpecificPropertyListeners {
    TestModel *test = [[TestModel alloc] init];
    __block NSUInteger dispatchCount = 0;
    
    [test observeChangeImmediately:self key:@"string" callback:^{
        dispatchCount++;
    }];
    
    test.string = @"test";
    test.int8 = 1;
    test.int16 = 2;
    
    XCTAssertEqual(dispatchCount, 1, "Dispatched once");
    
    test.string = nil;
    
    XCTAssertEqual(dispatchCount, 2, "Dispatched once");
}

- (void)testArrayListeners {
    TestModel *model = [[TestModel alloc] init];
    __block NSUInteger changedCount = 0;
    __block NSUInteger addCount = 0;
    __block NSUInteger removeCount = 0;
    
    [model observeChangeImmediately:self key:@"array" callback:^{
        changedCount++;
    }];
    
    [model observeCollectionAdd:self key:@"array" callback:^(ModelObject *model) {
        addCount++;
    }];
    
    [model observeCollectionRemove:self key:@"array" callback:^(ModelObject *model) {
        removeCount++;
    }];
    
    model.array = [model.array arrayByAddingObject:[[TestModel alloc] init]];
    model.array = @[[[TestModel alloc] init]];
    model.array = @[];
    model.array = @[[[TestModel alloc] init]];

    XCTAssertEqual(changedCount, 4 , "Dispatched four times");
    XCTAssertEqual(addCount, 3 , "Dispatched three times");
    XCTAssertEqual(removeCount, 2 , "Dispatched two times");
}

@end

