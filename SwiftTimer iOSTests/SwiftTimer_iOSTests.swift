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
        
        let timer = SwiftTimer(interval: .seconds(2)) {
            XCTAssertNotNil(nil)
        }
        timer.start()
    }
    
}
