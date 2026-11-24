// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Sentinel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sentinel", targets: ["Sentinel"])
    ],
    targets: [
        .executableTarget(
            name: "Sentinel",
            path: "Sentinel",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
