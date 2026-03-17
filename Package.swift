// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Fuckify",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "Fuckify",
            targets: ["Fuckify"],
        ),
    ],    
    dependencies: [
        .package(url: "https://github.com/vtourraine/acknowlist.git", from: "3.4.0"),
        .package(url: "https://github.com/Mijick/CalendarView.git", from: "1.1.1"),
        //.package(url: "https://github.com/DnV1eX/LiquidGlassKit.git", from: "1.0.1"),
        .package(path: "LiquidGlassKit"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.9.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.4.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.4"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "2.0.9"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
        //.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
        .package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.26.0"),
    ],
    targets: [
        .target(
            name: "Fuckify",
            dependencies: [
                .product(name: "AcknowList", package: "acknowlist"),
                .product(name: "MijickCalendarView", package: "CalendarView"),
                .product(name: "LiquidGlassKit", package: "LiquidGlassKit"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Perception", package: "swift-perception"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "Collections", package: "swift-collections"),
                //.product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "StructuredQueries", package: "swift-structured-queries"),
            ],
            path: "Fuckify",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=minimal"])
            ],

        ),
    ]
)
