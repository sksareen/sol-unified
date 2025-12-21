// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SolUnified",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SolUnified", targets: ["SolUnified"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SolUnified",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
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
