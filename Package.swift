// swift-tools-version: 6.0
import PackageDescription

/// The app and its widget are built by the Xcode project (project.yml); this
/// package holds the code they share, so `swift test` covers it without Xcode.
let package = Package(
    name: "AgentUsageKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentUsageCore", targets: ["AgentUsageCore"]),
        .library(name: "AgentUsageUI", targets: ["AgentUsageUI"]),
    ],
    targets: [
        .target(name: "AgentUsageCore"),
        .target(
            name: "AgentUsageUI",
            dependencies: ["AgentUsageCore"],
            exclude: ["Resources/ATTRIBUTION.md"],
            resources: [.copy("Resources/Logos")]
        ),
        .testTarget(
            name: "AgentUsageCoreTests",
            dependencies: ["AgentUsageCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
