// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iq-core-data-browser",
    products: [
        .library(
            name: "IQCoreDataBrowser",
            targets: ["IQCoreDataBrowser"]),
    ],
    targets: [
        .target(
            name: "IQCoreDataBrowser",
            path: "Sources/IQCoreDataBrowser",
            publicHeadersPath: "include"  // Apunta a la carpeta 'include' ara que SPM pugui trobar els fitxers .h
        ),
    ]
)

