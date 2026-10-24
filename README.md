![](logo.png)

[![](http://img.shields.io/badge/Swift5-blue.svg)]()    ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OSX%20%7C%20tvOS%20%7C%20watchOS%20-333333.svg) 

Simple and Elegant Timer

中文介绍：[打造一个优雅的Timer](https://github.com/100mango/zen/blob/master/%E6%89%93%E9%80%A0%E4%B8%80%E4%B8%AA%E4%BC%98%E9%9B%85%E7%9A%84Timer/make%20a%20timer.md)

## Compare with NSTimer
- No retain cycle
- Decouple with RunLoop 
- Support GCD queue
- Support dynamically changing interval
- Support closure syntax

## Usage


### single timer

~~~swift
//We need to maintain a strong reference to SwiftTimer. When self dealloc, timer will dealloc too. 
self.timer = SwiftTimer(interval: .seconds(2)) {
    print("fire")
}
self.timer.start()
~~~

### repeatic timer

~~~swift
timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) {
    print("fire")
}
timer.start()
~~~

dynamically changing interval

~~~swift
timer = SwiftTimer.repeaticTimer(interval: .seconds(5)) { timer in
	print("doSomething")
}
timer.start()  // print doSomething every 5 seconds

func speedUp(timer: SwiftTimer) {
	timer.rescheduleRepeating(interval: .seconds(1))
}
speedUp(timer) // print doSomething every 1 second 
~~~

### throttle

The closure will be called after interval you specified. It is invalid to call again in the interval.

~~~swift
SwiftTimer.throttle(interval: .seconds(0.5), identifier: "refresh") {
	refresh();
}
~~~


### debounce

The closure will be called after interval you specified. Calling again in the interval cancels the previous call.

~~~swift
SwiftTimer.debounce(interval: .seconds(0.5), identifier: "search") {
	search(inputText)
}
~~~


### count down timer

~~~swift
timer = SwiftCountDownTimer(interval: .fromSeconds(0.1), times: 10) { timer , leftTimes in
    label.text = "\(leftTimes)"
}
timer.start()
~~~



## Installation

### Swift Package Manager

SwiftTimer can be added as a Swift Package Manager dependency with Swift 5.0 or later.
The package exposes the `SwiftTimer` library and keeps the existing deployment targets:
iOS 8, macOS 10.11, tvOS 10, and watchOS 3. Your Xcode version may require a newer
deployment target. The package also builds on Linux using Foundation and Dispatch.

In Xcode, choose **File > Add Package Dependencies**, enter
`https://github.com/100mango/SwiftTimer.git`, and add the `SwiftTimer` product to your target.
While this migration is under review, select the `swiftpm-support` branch.
The `master` branch can be used only after this change is merged; the existing
`v1.0` and `1.1` tags do not contain a package manifest. Once a version containing
`Package.swift` is released, prefer that version for a stable dependency.

For a `Package.swift` dependency:

~~~swift
dependencies: [
    .package(url: "https://github.com/100mango/SwiftTimer.git", .branch("swiftpm-support"))
],
targets: [
    .target(name: "YourTarget", dependencies: ["SwiftTimer"])
]
~~~

Then use `import SwiftTimer` in your Swift files. The package compiles in Swift 5
language mode, including when used with a Swift 6 toolchain.

### Carthage

~~~
github "100mango/SwiftTimer"
~~~

## Testing

Run the cross-platform package tests with a current Swift toolchain:

~~~sh
swift test
swift test -c release
~~~

The package tests cover timers, countdowns, debounce, and throttle without UIKit.
The existing Xcode project and its iOS tests remain available for Apple-platform
validation; Linux package tests do not replace Apple SDK or device testing.
