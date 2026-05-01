// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ubu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ubu",
            dependencies: [],
            path: "Sources/Ubu",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "UbuTests",
            dependencies: ["ubu"],
            path: "Tests/UbuTests"
        )
    ]
)
