// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Sentinel",
    platforms: [
        .macOS(.v27)
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
    swiftLanguageModes: [.v5]
)
