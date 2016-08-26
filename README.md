![](logo.png)

[![](http://img.shields.io/badge/Swift-3-blue.svg)]()    ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OSX%20%7C%20tvOS%20%7C%20watchOS%20-333333.svg) 

Simple and Elegant Timer

中文介绍：[打造一个优雅的Timer](https://github.com/100mango/zen/blob/master/%E6%89%93%E9%80%A0%E4%B8%80%E4%B8%AA%E4%BC%98%E9%9B%85%E7%9A%84Timer/make%20a%20timer.md)

##Usage

###singleTimer

~~~swift
let timer = SwiftTimer(interval: .seconds(2)) {
    print("fire")
}
timer.start()
~~~

###repeaticTimer

~~~swift
let timer = SwiftTimer.repeaticTimer(interval: .seconds(1)) {
    print("fire")
}
timer.start()
~~~

###throttle

~~~swift
SwiftTimer.throttle(interval: .seconds(0.5), identifier: "throttle") {
	search(inputText)
}
~~~