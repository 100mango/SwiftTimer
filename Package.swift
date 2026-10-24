// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftTimer",
    platforms: [
        .iOS(.v8),
        .macOS(.v10_11),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "SwiftTimer", targets: ["SwiftTimer"])
    ],
    targets: [
        .target(
            name: "SwiftTimer",
            path: "Sources",
            exclude: [
                "Info-iOS.plist",
                "Info-macOS.plist",
                "Info-tvOS.plist",
                "Info-watchOS.plist",
                "SwiftTimer.h"
            ]
        ),
        .testTarget(
            name: "SwiftTimerTests",
            dependencies: ["SwiftTimer"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
