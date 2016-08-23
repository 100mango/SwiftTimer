//
//  SwiftTimer.swift
//  SwiftTimer
//
//  Created by mangofang on 16/8/23.
//
//

import Foundation

class SwiftTimer {
    
    private let internalTimer: DispatchSourceTimer
    
    private var isRunning = false
    
    init(interval: DispatchTimeInterval, repeats: Bool = false, queue: DispatchQueue = .main , handler: @escaping () -> Void) {
        
        internalTimer = DispatchSource.makeTimerSource(queue: queue)
        internalTimer.setEventHandler(handler: handler)
        if repeats {
            internalTimer.scheduleRepeating(deadline: .now() + interval, interval: interval)
        } else {
            internalTimer.scheduleOneshot(deadline: .now() + interval)
        }
    }
    
    static func repeaticTimer(interval: DispatchTimeInterval, queue: DispatchQueue = .main , handler: @escaping () -> Void) -> SwiftTimer {
        return SwiftTimer(interval: interval, repeats: true, queue: queue, handler: handler)
    }
    
    deinit {
        print("deinit")
    }
    
    func start() {
        if !isRunning {
            internalTimer.resume()
            isRunning = true
        }
    }
    
    func stop() {
        if isRunning {
            internalTimer.suspend()
            isRunning = false
        }
    }
    
}

// Throttle
extension SwiftTimer {
    private static var timers = [String:DispatchSourceTimer]()
    
    //提供identifier的原因是标记不同的handler,因为闭包不能做equal比较所以我们只能自己提供标记
    //http://stackoverflow.com/questions/24111984/how-do-you-test-functions-and-closures-for-equality
    static func throttle(interval: DispatchTimeInterval, identifier: String, queue: DispatchQueue = .main , handler: @escaping () -> Void ) {
        
        if let previousTimer = timers[identifier] {
            previousTimer.cancel()
        }
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.scheduleOneshot(deadline: .now() + interval)
        timer.setEventHandler {
            handler()
            timer.cancel()
            timers.removeValue(forKey: identifier)
        }
        timer.resume()
        timers[identifier] = timer
    }
}

public extension DispatchTimeInterval {
    
    public static func fromSeconds(_ seconds: Double) -> DispatchTimeInterval {
        return .nanoseconds(Int(seconds * Double(NSEC_PER_SEC)))
    }
}
