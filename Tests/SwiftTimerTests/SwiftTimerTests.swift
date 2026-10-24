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

    func testThrottleCanScheduleSameIdentifierFromItsHandler() {
        let identifier = UUID().uuidString
        defer { SwiftTimer.cancelThrottlingTimer(identifier: identifier) }
        let completed = expectation(description: "Reentrant throttle fires three times")
        var count = 0
        func schedule() {
            SwiftTimer.throttle(interval: .milliseconds(0), identifier: identifier) {
                count += 1
                if count < 3 {
                    schedule()
                } else {
                    completed.fulfill()
                }
            }
        }

        schedule()
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(count, 3)
    }

    func testReentrantDebounceRemainsCancellableAfterOriginalHandlerReturns() {
        let identifier = UUID().uuidString
        let queue = DispatchQueue(label: "SwiftTimerTests.reentrantDebounce")
        queue.suspend()
        let cancelled = expectation(description: "Replacement remains cancellable")
        cancelled.isInverted = true
        let drained = expectation(description: "Replacement queue runs")
        SwiftTimer.debounce(interval: .milliseconds(0), identifier: identifier) {
            SwiftTimer.debounce(interval: .milliseconds(0), identifier: identifier, queue: queue) {
                cancelled.fulfill()
            }
            DispatchQueue.main.async {
                SwiftTimer.cancelThrottlingTimer(identifier: identifier)
                queue.resume()
                queue.async { drained.fulfill() }
            }
        }

        wait(for: [drained, cancelled], timeout: 0.2)
        SwiftTimer.cancelThrottlingTimer(identifier: identifier)
    }

    func testConcurrentIdentifiersAndCancellationAreIndependent() {
        let prefix = UUID().uuidString
        let completed = expectation(description: "All uncancelled callbacks fire")
        completed.expectedFulfillmentCount = 50
        completed.assertForOverFulfill = true
        var values = Set<Int>()

        // Callbacks use the main queue, which cannot run until registration returns.
        // This makes cancellation deterministic while registrations overlap on workers.
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let identifier = "\(prefix)-\(index)"
            SwiftTimer.debounce(interval: .milliseconds(0), identifier: identifier) {
                XCTAssertEqual(index % 2, 0)
                values.insert(index)
                completed.fulfill()
            }
            if index % 2 != 0 {
                SwiftTimer.cancelThrottlingTimer(identifier: identifier)
            }
        }

        wait(for: [completed], timeout: 2)
        XCTAssertEqual(values, Set(stride(from: 0, to: 100, by: 2)))
        for index in 0..<100 {
            SwiftTimer.cancelThrottlingTimer(identifier: "\(prefix)-\(index)")
        }
    }

    func testDebounceAndThrottleUseRequestedQueue() {
        let queue = DispatchQueue(label: "SwiftTimerTests.workItems")
        let key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "workItems")
        let completed = expectation(description: "Callbacks use requested queue")
        completed.expectedFulfillmentCount = 2
        let handler = {
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "workItems")
            completed.fulfill()
        }

        SwiftTimer.debounce(interval: .milliseconds(0), identifier: UUID().uuidString, queue: queue, handler: handler)
        SwiftTimer.throttle(interval: .milliseconds(0), identifier: UUID().uuidString, queue: queue, handler: handler)
        wait(for: [completed], timeout: 2)
    }

    func testConcurrentDebounceWithSameIdentifierOnlyRunsLatestRegistration() {
        assertConcurrentRegistrationsOnlyFireOnce(replacing: true)
    }

    func testConcurrentThrottleWithSameIdentifierOnlyRunsFirstRegistration() {
        assertConcurrentRegistrationsOnlyFireOnce(replacing: false)
    }

    private func assertConcurrentRegistrationsOnlyFireOnce(replacing: Bool) {
        let identifier = UUID().uuidString
        let queue = DispatchQueue(label: "SwiftTimerTests.sameIdentifier")
        queue.suspend()
        let fired = expectation(description: "One registration wins")
        fired.assertForOverFulfill = true
        var count = 0
        let selectedHandler = {
            count += 1
            fired.fulfill()
        }
        if !replacing {
            SwiftTimer.throttle(interval: .milliseconds(0), identifier: identifier, queue: queue, handler: selectedHandler)
        }
        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            let handler = {
                XCTFail("A superseded or throttled registration must not fire")
            }
            if replacing {
                SwiftTimer.debounce(interval: .milliseconds(0), identifier: identifier, queue: queue, handler: handler)
            } else {
                SwiftTimer.throttle(interval: .milliseconds(0), identifier: identifier, queue: queue, handler: handler)
            }
        }
        if replacing {
            SwiftTimer.debounce(interval: .milliseconds(0), identifier: identifier, queue: queue, handler: selectedHandler)
        }
        queue.resume()
        wait(for: [fired], timeout: 2)
        queue.sync { XCTAssertEqual(count, 1) }
        SwiftTimer.cancelThrottlingTimer(identifier: identifier)
    }

    func testRescheduleRepeatingDoesNotChangeSingleTimer() {
        let completed = expectation(description: "Single timer keeps its deadline")
        let timer = SwiftTimer(interval: .milliseconds(0)) { _ in completed.fulfill() }
        timer.rescheduleRepeating(interval: .seconds(60))
        timer.start()
        wait(for: [completed], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testRepeatingTimerCanFireReentrantly() {
        var count = 0
        let timer = SwiftTimer.repeaticTimer(interval: .seconds(60)) { timer in
            count += 1
            if count < 3 {
                timer.fire()
            }
        }

        timer.fire()
        XCTAssertEqual(count, 3)
    }

    func testTimerCanReleaseLastReferenceFromCallback() {
        let completed = expectation(description: "Timer releases itself from callback")
        var timer: SwiftTimer?
        weak var reference: SwiftTimer?
        timer = SwiftTimer.repeaticTimer(interval: .milliseconds(10)) { firingTimer in
            firingTimer.suspend()
            timer = nil
            completed.fulfill()
        }
        reference = timer
        timer?.start()

        wait(for: [completed], timeout: 2)
        XCTAssertNil(reference)
    }

    func testReplacingHandlerReleasesItsCapturedObject() {
        let released = expectation(description: "Old handler releases its capture")
        var timer: SwiftTimer?
        do {
            let probe = LifetimeProbe { released.fulfill() }
            timer = SwiftTimer(interval: .seconds(60)) { [probe] _ in
                withExtendedLifetime(probe) {}
            }
        }
        timer?.rescheduleHandler { _ in }

        wait(for: [released], timeout: 2)
        withExtendedLifetime(timer) {}
    }

    func testNonPositiveCountdownNeverCallsHandler() {
        let unexpected = expectation(description: "Nonpositive countdown stays silent")
        unexpected.isInverted = true
        let zero = SwiftCountDownTimer(interval: .milliseconds(0), times: 0) { _, _ in unexpected.fulfill() }
        let negative = SwiftCountDownTimer(interval: .milliseconds(0), times: -1) { _, _ in unexpected.fulfill() }
        zero.start()
        negative.start()

        wait(for: [unexpected], timeout: 0.1)
        zero.suspend()
        negative.suspend()
        withExtendedLifetime((zero, negative)) {}
    }

    func testCountdownCanSuspendInHandlerAndResumeWithoutResetting() {
        let paused = expectation(description: "Countdown pauses after first event")
        let completed = expectation(description: "Countdown resumes from remaining count")
        var values: [Int] = []
        let timer = SwiftCountDownTimer(interval: .milliseconds(10), times: 3) { timer, remaining in
            values.append(remaining)
            if remaining == 2 {
                timer.suspend()
                paused.fulfill()
            } else if remaining == 0 {
                timer.suspend()
                completed.fulfill()
            }
        }
        timer.start()
        wait(for: [paused], timeout: 2)
        XCTAssertEqual(values, [2])
        timer.start()
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(values, [2, 1, 0])
        withExtendedLifetime(timer) {}
    }

    func testCountdownCanResetFromItsCompletionHandler() {
        let completed = expectation(description: "Countdown resets from callback")
        var values: [Int] = []
        let timer = SwiftCountDownTimer(interval: .milliseconds(10), times: 2) { timer, remaining in
            values.append(remaining)
            if values == [1, 0] {
                timer.reCountDown()
            } else if values == [1, 0, 1, 0] {
                timer.suspend()
                completed.fulfill()
            }
        }
        timer.start()
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(values, [1, 0, 1, 0])
        withExtendedLifetime(timer) {}
    }

    func testCountdownCanReleaseLastReferenceFromCallback() {
        let completed = expectation(description: "Countdown releases itself from callback")
        var timer: SwiftCountDownTimer?
        weak var reference: SwiftCountDownTimer?
        timer = SwiftCountDownTimer(interval: .milliseconds(10), times: 1) { _, remaining in
            XCTAssertEqual(remaining, 0)
            timer = nil
            completed.fulfill()
        }
        reference = timer
        timer?.start()
        wait(for: [completed], timeout: 2)
        XCTAssertNil(reference)
    }

    func testSecondsConversionHandlesZeroSubmillisecondAndNegativeValues() {
        for (input, expected) in [(0.0, 0), (0.0009, 0), (1.9999, 1999), (-1.25, -1250)] {
            switch DispatchTimeInterval.fromSeconds(input) {
            case .milliseconds(let value):
                XCTAssertEqual(value, expected)
            default:
                XCTFail("Seconds must be represented as milliseconds")
            }
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

private final class LifetimeProbe {
    private let onDeinit: () -> Void

    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit()
    }
}
