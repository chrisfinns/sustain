// swift-tools-version: 6.2
import PackageDescription

// Foundation-only rules for Sustain. Builds and tests on Linux, so cloud sessions can run `swift test`.
let package = Package(
    name: "SustainCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SustainCore", targets: ["SustainCore"]),
    ],
    targets: [
        .target(name: "SustainCore"),
        .testTarget(
            name: "SustainCoreTests",
            dependencies: ["SustainCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
