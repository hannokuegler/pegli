// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pegli",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pegli",
            path: "Sources/Pegli",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("SystemConfiguration"),
            ]
        )
    ]
)
