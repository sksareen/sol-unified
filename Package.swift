// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SolUnified",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SolUnified", targets: ["SolUnified"])
    ],
    targets: [
        .executableTarget(
            name: "SolUnified",
            dependencies: [],
            path: "SolUnified",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
