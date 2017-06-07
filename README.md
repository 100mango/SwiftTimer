![](logo.png)

[![](http://img.shields.io/badge/Swift-3-blue.svg)]()    ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OSX%20%7C%20tvOS%20%7C%20watchOS%20-333333.svg) 

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
let timer = SwiftTimer(interval: .seconds(2)) {
    print("fire")
}
timer.start()
~~~

### repeatic timer

~~~swift
let timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) {
    print("fire")
}
timer.start()
~~~

dynamically changing interval

~~~swift
let timer = SwiftTimer.repeaticTimer(interval: .seconds(5)) { timer in
	print("doSomething")
}
timer.start()  // print doSomething every 5 seconds

func speedUp(timer: SwiftTimer) {
	timer.rescheduleRepeating(interval: .seconds(1))
}
speedUp(timer) // print doSomething every 1 second 
~~~

### throttle

~~~swift
SwiftTimer.throttle(interval: .seconds(0.5), identifier: "throttle") {
	search(inputText)
}
~~~

### count down timer

~~~swift
let timer = SwiftCountDownTimer(interval: .fromSeconds(0.1), times: 10) { timer , leftTimes in
    label.text = "\(leftTimes)"
}
timer.start()
~~~



## Installation

Carthage:

~~~
github "100mango/SwiftTimer"
~~~