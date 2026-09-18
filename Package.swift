// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Poptro",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Poptro",
            dependencies: ["KeyboardShortcuts", "Sparkle"],
            path: "Sources/Poptro",
            resources: [.copy("Resources/GoogleG.png")]
        ),
        .testTarget(
            name: "PoptroTests",
            dependencies: ["Poptro"],
            path: "Tests/PoptroTests"
        )
    ]
)
