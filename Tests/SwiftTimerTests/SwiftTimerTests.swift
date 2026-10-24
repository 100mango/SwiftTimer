import Dispatch
import Foundation
import XCTest
import SwiftTimer

final class SwiftTimerTests: XCTestCase {
    func testSingleTimerFiresOnce() {
        let fired = expectation(description: "Single timer fires")
        fired.assertForOverFulfill = true
        var count = 0
        let timer = SwiftTimer(interval: .milliseconds(10)) { _ in
            count += 1
            fired.fulfill()
        }

        XCTAssertFalse(timer.repeats)
        timer.start()
        wait(for: [fired], timeout: 2)
        waitForMainQueue(milliseconds: 50)
        XCTAssertEqual(count, 1)
        withExtendedLifetime(timer) {}
    }

    func testTimerWaitsForStart() {
        var count = 0
        let fired = expectation(description: "Timer starts after suspension")
        let timer = SwiftTimer(interval: .milliseconds(10)) { _ in
            count += 1
            fired.fulfill()
        }

        waitForMainQueue(milliseconds: 50)
        XCTAssertEqual(count, 0)
        timer.start()
        wait(for: [fired], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testRepeatingTimerCanSuspendAndResume() {
        let firstRun = expectation(description: "First repeated events")
        let resumed = expectation(description: "Timer resumes")
        var count = 0
        let timer = SwiftTimer.repeaticTimer(interval: .milliseconds(10)) { timer in
            count += 1
            if count == 2 {
                timer.suspend()
                firstRun.fulfill()
            } else if count == 3 {
                timer.suspend()
                resumed.fulfill()
            }
        }

        XCTAssertTrue(timer.repeats)
        timer.start()
        timer.start() // Repeated starts must not over-resume the dispatch source.
        wait(for: [firstRun], timeout: 2)
        timer.suspend() // Repeated suspensions must not over-suspend it either.
        waitForMainQueue(milliseconds: 50)
        XCTAssertEqual(count, 2)
        timer.start()
        wait(for: [resumed], timeout: 2)
        XCTAssertEqual(count, 3)
        withExtendedLifetime(timer) {}
    }

    func testManualFireUsesCurrentHandler() {
        var originalCount = 0
        var replacementCount = 0
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(60)) { _ in
            originalCount += 1
        }

        timer.fire()
        timer.rescheduleHandler { _ in replacementCount += 1 }
        timer.fire()
        XCTAssertEqual(originalCount, 1)
        XCTAssertEqual(replacementCount, 1)
    }

    func testManualFireCancelsScheduledSingleTimer() {
        var count = 0
        let timer = SwiftTimer(interval: .milliseconds(10)) { _ in count += 1 }

        timer.fire()
        timer.start()
        waitForMainQueue(milliseconds: 50)
        XCTAssertEqual(count, 1)
        withExtendedLifetime(timer) {}
    }

    func testRescheduledHandlerReceivesScheduledEvent() {
        let fired = expectation(description: "Replacement handler receives event")
        let timer = SwiftTimer(interval: .milliseconds(10)) { _ in
            XCTFail("The original handler must be replaced")
        }
        timer.rescheduleHandler { _ in fired.fulfill() }

        timer.start()
        wait(for: [fired], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testRepeatingIntervalCanBeRescheduled() {
        let fired = expectation(description: "Rescheduled timer fires")
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(60)) { timer in
            timer.suspend()
            fired.fulfill()
        }

        timer.start()
        timer.rescheduleRepeating(interval: .milliseconds(10))
        wait(for: [fired], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testTimerDoesNotRetainItselfWhileRunningOrSuspended() {
        for shouldStart in [false, true] {
            weak var reference: SwiftTimer?
            do {
                let timer = SwiftTimer.repeaticTimer(interval: .seconds(60)) { _ in }
                reference = timer
                if shouldStart {
                    timer.start()
                }
            }
            XCTAssertNil(reference)
        }
    }

    func testTimerUsesRequestedQueue() {
        let queue = DispatchQueue(label: "SwiftTimerTests.custom")
        let key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "custom")
        let fired = expectation(description: "Timer fires on requested queue")
        let timer = SwiftTimer(interval: .milliseconds(10), queue: queue) { _ in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "custom")
            fired.fulfill()
        }

        timer.start()
        wait(for: [fired], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testDebounceOnlyInvokesLatestHandler() {
        let identifier = UUID().uuidString
        defer { SwiftTimer.cancelThrottlingTimer(identifier: identifier) }
        let fired = expectation(description: "Latest debounced handler fires")
        fired.assertForOverFulfill = true

        for _ in 0..<3 {
            SwiftTimer.debounce(interval: .milliseconds(10), identifier: identifier) {
                XCTFail("Earlier debounce handlers must be cancelled")
            }
        }
        SwiftTimer.debounce(interval: .milliseconds(10), identifier: identifier) {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 2)
        waitForMainQueue(milliseconds: 50)
    }

    func testThrottleOnlyInvokesFirstHandlerWithinWindowAndCanBeReused() {
        let identifier = UUID().uuidString
        defer { SwiftTimer.cancelThrottlingTimer(identifier: identifier) }
        let first = expectation(description: "First throttled handler fires")
        let second = expectation(description: "Identifier is reusable after firing")

        SwiftTimer.throttle(interval: .milliseconds(10), identifier: identifier) {
            first.fulfill()
        }
        for _ in 0..<3 {
            SwiftTimer.throttle(interval: .milliseconds(10), identifier: identifier) {
                XCTFail("Calls within the throttle window must be ignored")
            }
        }
        wait(for: [first], timeout: 2)

        SwiftTimer.throttle(interval: .milliseconds(10), identifier: identifier) {
            second.fulfill()
        }
        wait(for: [second], timeout: 2)
    }

    func testCancellingPendingDebounceAndThrottlePreventsDelivery() {
        let debounceID = UUID().uuidString
        let throttleID = UUID().uuidString
        let cancelled = expectation(description: "Cancelled handlers do not fire")
        cancelled.isInverted = true

        SwiftTimer.debounce(interval: .milliseconds(10), identifier: debounceID) {
            cancelled.fulfill()
        }
        SwiftTimer.throttle(interval: .milliseconds(10), identifier: throttleID) {
            cancelled.fulfill()
        }
        SwiftTimer.cancelThrottlingTimer(identifier: debounceID)
        SwiftTimer.cancelThrottlingTimer(identifier: throttleID)
        SwiftTimer.cancelThrottlingTimer(identifier: "missing")

        wait(for: [cancelled], timeout: 0.1)
    }

    func testCountdownStopsAtZeroAndCanRestart() {
        let first = expectation(description: "Countdown reaches zero")
        let second = expectation(description: "Reset countdown reaches zero")
        var values: [Int] = []
        var restarted = false
        let timer = SwiftCountDownTimer(interval: .milliseconds(10), times: 3) { _, remaining in
            values.append(remaining)
            if remaining == 0 {
                (restarted ? second : first).fulfill()
            }
        }

        timer.start()
        wait(for: [first], timeout: 2)
        waitForMainQueue(milliseconds: 50)
        XCTAssertEqual(values, [2, 1, 0])

        restarted = true
        timer.reCountDown()
        timer.start()
        wait(for: [second], timeout: 2)
        timer.suspend()
        XCTAssertEqual(values, [2, 1, 0, 2, 1, 0])
        withExtendedLifetime(timer) {}
    }

    func testSecondsConversionUsesMilliseconds() {
        switch DispatchTimeInterval.fromSeconds(1.25) {
        case .milliseconds(let value):
            XCTAssertEqual(value, 1_250)
        default:
            XCTFail("Seconds must be represented as milliseconds")
        }
    }

    private func waitForMainQueue(milliseconds: Int) {
        let elapsed = expectation(description: "Main queue observation window")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) {
            elapsed.fulfill()
        }
        wait(for: [elapsed], timeout: 2)
    }
}
