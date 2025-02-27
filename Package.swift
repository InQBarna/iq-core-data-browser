// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IQCoreDataBrowser",
        defaultLocalization: "en",    
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "IQCoreDataBrowser",
            targets: ["IQCoreDataBrowser"]),
    ],
    targets: [
        .target(
            name: "IQCoreDataBrowser",
            path: "Sources/IQCoreDataBrowser",
            publicHeadersPath: "include"
        ),
    ]
)

