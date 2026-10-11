// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MaruKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MaruCore", targets: ["MaruCore"]),
        .library(name: "MaruDatabase", targets: ["MaruDatabase"]),
        .library(name: "MaruNotifications", targets: ["MaruNotifications"]),
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
        .testTarget(name: "MaruCoreTests", dependencies: ["MaruCore"]),
        .testTarget(name: "MaruNotificationsTests", dependencies: ["MaruCore", "MaruNotifications"]),
        .testTarget(
            name: "MaruDatabaseTests",
            dependencies: ["MaruCore", "MaruDatabase", .product(name: "GRDB", package: "GRDB.swift")]
        ),
    ]
)
