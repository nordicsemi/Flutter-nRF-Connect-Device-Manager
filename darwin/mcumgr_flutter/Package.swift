// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mcumgr_flutter",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "mcumgr-flutter", targets: ["mcumgr_flutter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nordicsemi/IOS-nRF-Connect-Device-Manager.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.0.0"),
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "mcumgr_flutter",
            dependencies: [
                .product(name: "iOSMcuManagerLibrary", package: "ios-nrf-connect-device-manager"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            exclude: [
                "McumgrFlutterPlugin.h",
                "McumgrFlutterPlugin.m",
            ],
            resources: [
                // TODO: If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        ),
    ]
)
