// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StatusLight",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/microsoftgraph/msgraph-sdk-objc-models", from: "3.0.0"),
        .package(url: "https://github.com/Microsoft/kiota-authentication-azure-swift", from: "1.0.0"),
        .package(url: "https://github.com/microsoft/kiota-http-swift", from: "1.0.0"),
        .package(url: "https://github.com/microsoft/kiota-serialization-json-swift", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "StatusLight",
            dependencies: [
                .product(name: "MicrosoftGraphCore", package: "msgraph-sdk-objc-models"),
                .product(name: "KiotaAuthentication", package: "kiota-authentication-azure-swift"),
                .product(name: "KiotaHttp", package: "kiota-http-swift"),
                .product(name: "KiotaSerialization", package: "kiota-serialization-json-swift")
            ]
        )
    ]
)