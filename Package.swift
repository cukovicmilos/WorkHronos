// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkHronos",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "WorkHronosKit",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "WorkHronos",
            dependencies: [
                "WorkHronosKit",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        // CLT nema XCTest/Testing module, pa su testovi executable target
        .executableTarget(
            name: "workhronos-tests",
            dependencies: [
                "WorkHronosKit",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
