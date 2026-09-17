// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuBarTranslator",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MenuBarTranslator",
            dependencies: ["KeyboardShortcuts", "Sparkle"],
            path: "Sources/MenuBarTranslator"
        ),
        .testTarget(
            name: "MenuBarTranslatorTests",
            dependencies: ["MenuBarTranslator"],
            path: "Tests/MenuBarTranslatorTests"
        )
    ]
)
