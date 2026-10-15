// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MaruKit",
    defaultLocalization: "en",
    // The Watch app links only `MaruCore` (D071).
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "MaruCore", targets: ["MaruCore"]),
        .library(name: "MaruDatabase", targets: ["MaruDatabase"]),
        .library(name: "MaruNotifications", targets: ["MaruNotifications"]),
        .library(name: "MaruAnalytics", targets: ["MaruAnalytics"]),
    ],
    dependencies: [
        // Pinned to one release. See docs/third-party-licenses.md before you change the version.
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
    ],
    targets: [
        .target(name: "MaruCore"),
        // The only target that imports GRDB. `MaruCore` stays free of third-party code.
        .target(
            name: "MaruDatabase",
            dependencies: ["MaruCore", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        // The only target that imports UserNotifications. The reminder rules are in `MaruCore`.
        .target(name: "MaruNotifications", dependencies: ["MaruCore"], resources: [.process("Resources")]),
        // The only sender of analytics events. It uses URLSession and no vendor SDK (D052).
        .target(name: "MaruAnalytics", dependencies: ["MaruCore"]),
        .testTarget(name: "MaruCoreTests", dependencies: ["MaruCore"]),
        .testTarget(name: "MaruAnalyticsTests", dependencies: ["MaruCore", "MaruAnalytics"]),
        .testTarget(name: "MaruNotificationsTests", dependencies: ["MaruCore", "MaruNotifications"]),
        // The simulator of iOS notifications around the real engines (D086). See `Phone.swift`.
        .testTarget(
            name: "MaruNotificationSimulationTests",
            dependencies: ["MaruCore", "MaruDatabase", "MaruNotifications", .product(name: "GRDB", package: "GRDB.swift")],
            // Databases that earlier versions of the app left. See `UpgradeTests`.
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MaruDatabaseTests",
            dependencies: ["MaruCore", "MaruDatabase", .product(name: "GRDB", package: "GRDB.swift")]
        ),
    ]
)
