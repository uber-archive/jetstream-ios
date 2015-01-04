//
//  ObjectiveCScopeTests.m
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

@interface ObjectiveCScopeTests : XCTestCase

@property (nonatomic, strong) TestModel *parent;
@property (nonatomic, strong) TestModel *child;
@property (nonatomic, strong) TestModel *child2;
@property (nonatomic, strong) TestModel *child3;
@property (nonatomic, strong) Scope *scope;

@end

@implementation ObjectiveCScopeTests

- (void)setUp {
    [super setUp];
    self.parent = [[TestModel alloc] init];
    self.child = [[TestModel alloc] init];
    self.child2 = [[TestModel alloc] init];
    self.child3 = [[TestModel alloc] init];
    self.scope = [[Scope alloc] initWithName:@"Testing" changeInterval:0.01];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testScopeFragmentCountWhenAdding {
    [self.parent setScopeAndMakeRootModel:self.scope];
    self.parent.array = @[self.child];
    
    NSArray *fragments1 = [self.scope getAndClearSyncFragments];
    
    XCTAssertEqual(fragments1.count, 2, @"Add fragment should be created for child");
    
    self.parent.array = [self.parent.array arrayByAddingObject:self.child2];
    
    NSArray *fragments2 = [self.scope getAndClearSyncFragments];
    
    SyncFragment *addFragment;
    for (SyncFragment *fragment in fragments2) {
        if ([fragment.typeRawValue isEqualToString:@"add"]) {
            addFragment = fragment;
        }
    }
    
    XCTAssertEqual(fragments2.count, 2, @"Add fragment should be created for child2");
    XCTAssertNotNil(addFragment, "Should be an add fragment");
    XCTAssertEqual(addFragment.objectUUID, self.child2.uuid, @"Should match child2's UUID");
}

@end
