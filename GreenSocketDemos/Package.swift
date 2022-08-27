// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GreenSocketDemos",
    products: [
        .executable(
            name: "EchoServerDemo",
            targets: ["EchoServerDemo"]),
        .executable(
            name: "EchoClientDemo",
            targets: ["EchoClientDemo"]),
        .executable(
            name: "SimpleUDPDemo",
            targets: ["SimpleUDPDemo"]),
        .executable(
            name: "SimpleTCPMessageDemo",
            targets: ["SimpleTCPMessageDemo"]),
    ],
    dependencies: [
        .package(name: "GreenSocket", path: ".."),
    ],
    targets: [
        .target(
            name: "EchoServerDemo",
            dependencies: [
                .product(name: "Socket", package: "GreenSocket"),
            ]),
        .target(
            name: "EchoClientDemo",
            dependencies: [
                .product(name: "Socket", package: "GreenSocket"),
            ]),
        .target(
            name: "SimpleUDPDemo",
            dependencies: [
                .product(name: "Socket", package: "GreenSocket"),
            ]),
        .target(
            name: "SimpleTCPMessageDemo",
            dependencies: [
                .product(name: "Socket", package: "GreenSocket"),
            ]),
    ]
)
