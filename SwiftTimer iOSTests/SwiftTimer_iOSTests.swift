//
//  SwiftTimer_iOSTests.swift
//  SwiftTimer iOSTests
//
//  Created by mangofang on 16/8/23.
//
//

import XCTest

class SwiftTimer_iOSTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSingleTimer() {
        
        let expectation = self.expectation(description: "timer fire")

        let timer = SwiftTimer(interval: .seconds(2)) { _ in
            print("timer fire")
            expectation.fulfill()
        }
        timer.start()
        self.waitForExpectations(timeout: 2.01, handler: nil)
    }
    
    func testRepeaticTimer() {
        
        let expectation = self.expectation(description: "timer fire")

        var count = 0
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) { _ in
            count = count + 1
            if count == 2 {
                expectation.fulfill()
            }
        }
        timer.start()
        self.waitForExpectations(timeout: 2.01, handler: nil)
    }
    
    func testThrottle() {
        
        let expectation = self.expectation(description: "throttle")
        
        var count = 0
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) { _ in
            
            SwiftTimer.throttle(interval: .fromSeconds(1.5), identifier: "not pass") {
                XCTFail("should not pass")
                expectation.fulfill()
            }
            
            SwiftTimer.throttle(interval: .fromSeconds(0.5), identifier:  "pass") {
                count = count + 1
                if count == 4 {
                    expectation.fulfill()
                }
            }
        }
        timer.start()
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testRescheduleRepeating() {
        
        let expectation = self.expectation(description: "rescheduleRepeating")        
        
        var count = 0
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) { timer in
            count = count + 1
            print(Date())
            if count == 3 {
                timer.rescheduleRepeating(interval: .seconds(3))
            }
            if count == 4 {
                expectation.fulfill()
            }
        }
        timer.start()
        self.waitForExpectations(timeout: 6.1, handler: nil)
    }
}
