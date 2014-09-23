//
//  JetstreamTests.swift
//  JetstreamTests
//
//  Created by Tuomas Artman on 9/18/14.
//  Copyright (c) 2014 Uber. All rights reserved.
//

import UIKit
import XCTest


class TreeChangeTests: XCTestCase {
    
    var parent = TestModel()
    var child = TestModel()
    var child2 = TestModel()
    var child3 = TestModel()
    
    var attachCount = [0, 0, 0, 0]
    var detachCount = [0, 0, 0, 0]
    var moveCount = [0, 0, 0, 0]
    
    override func setUp() {
        parent = TestModel()
        child = TestModel()
        child2 = TestModel()
        child3 = TestModel()
        
        attachCount = [0, 0, 0, 0]
        detachCount = [0, 0, 0, 0]
        moveCount = [0, 0, 0, 0]
        
        var i = 0
        for object in [parent, child, child2, child3] {
            func assignListeners(index: Int) -> Void {
                object.onAttach.listen(self, callback: { (parent, keyPath) -> Void in
                    self.attachCount[index] += 1
                })
                object.onDetach.listen(self, callback: { (parent, keyPath) -> Void in
                    self.detachCount[index] += 1
                })
                object.onMove.listen(self, callback: { (parent, keyPath) -> Void in
                    self.moveCount[index] += 1
                })
            }
            assignListeners(i++)
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testAssigmentAndRemoval() {
        parent.root = true
        parent.childModel = child
        parent.childModel = child2
        parent.childModel = child3
        parent.childModel = nil
        
        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 1 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 1 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 1 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 1 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 1 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
    }
 
    func testChainedAddition() {
        parent.root = true
        child.childModel = child2
        child2.childModel = child3
        
        XCTAssertEqual(attachCount[1], 0 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 0 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 0 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 0 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 0 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 0 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")

        parent.childModel = child
        
        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 0 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 1 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 0 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 1 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 0 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
        
        parent.childModel = nil
        
        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 1 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 1 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 1 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 1 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 1 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
    }
    
    func testObserveActualyAssigments() {
        parent.root = true
        parent.childModel = child
        parent.childModel = child
        parent.childModel = nil
        parent.childModel = nil

        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 1 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
    }
    
    func testChainedRemoval() {
        parent.root = true
        parent.childModel = child
        parent.childModel = child2
        parent.childModel = child3
        parent.childModel = nil
        
        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 1 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 1 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 1 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 1 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 1 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
    }

    func testMovingWithoutRoot() {
        parent.root = false
        parent.childModel = child
        child.childModel = child2
        child2.childModel = child3
        child.childModel2 = child2

        XCTAssertEqual(attachCount[1], 0 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 0 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 0 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 0 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 0 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 0 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 0 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
    }
    
    func testMoving() {
        parent.root = true
        parent.childModel = child
        child.childModel = child2
        child2.childModel = child3
        child.childModel2 = child2
        
        XCTAssertEqual(attachCount[1], 1 , "Correct amount of attaches observed for child")
        XCTAssertEqual(detachCount[1], 0 , "Correct amount of detaches observed for child")
        XCTAssertEqual(moveCount[1], 0 , "Correct amount of moves observed for child")
        
        XCTAssertEqual(attachCount[2], 1 , "Correct amount of attaches observed for child2")
        XCTAssertEqual(detachCount[2], 0 , "Correct amount of detaches observed for child2")
        XCTAssertEqual(moveCount[2], 1 , "Correct amount of moves observed for child2")
        
        XCTAssertEqual(attachCount[3], 1 , "Correct amount of attaches observed for child3")
        XCTAssertEqual(detachCount[3], 0 , "Correct amount of detaches observed for child3")
        XCTAssertEqual(moveCount[3], 0 , "Correct amount of moves observed for child3")
    }
}
