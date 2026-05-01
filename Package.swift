// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ubu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Ubu",
            dependencies: [],
            path: "Sources/Ubu",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "UbuTests",
            dependencies: ["Ubu"],
            path: "Tests/UbuTests"
        )
    ]
)
