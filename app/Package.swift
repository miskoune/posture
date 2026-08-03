// swift-tools-version: 5.9
import PackageDescription

// Two targets, one boundary. PostureCore holds the rules and imports nothing
// but Foundation, so it compiles and tests anywhere. PostureApp holds the
// camera, the notifications and the menu bar — every macOS framework lives on
// that side of the line and none of it can leak inward.
let package = Package(
    name: "Posture",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Posture", targets: ["PostureApp"]),
        .library(name: "PostureCore", targets: ["PostureCore"])
    ],
    targets: [
        .target(name: "PostureCore"),
        .executableTarget(name: "PostureApp", dependencies: ["PostureCore"]),
        .testTarget(name: "PostureCoreTests", dependencies: ["PostureCore"])
    ]
)
