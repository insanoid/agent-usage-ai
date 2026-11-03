// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentUsageMobile",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "UsageMobileCore", targets: ["UsageMobileCore"])],
    targets: [
        .target(name: "UsageMobileCore", path: "Shared"),
        .testTarget(name: "UsageMobileCoreTests", dependencies: ["UsageMobileCore"], path: "Tests"),
    ]
)
