// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ubu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ubu",
            path: "Sources/Ubu"
        ),
        .testTarget(
            name: "UbuTests",
            dependencies: ["ubu"],
            path: "Tests/UbuTests"
        )
    ]
)
