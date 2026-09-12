// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacbookDuo", defaultLocalization: "en", platforms: [.macOS(.v13)], products: [
    .executable(name: "MacbookDuo", targets: ["MacbookDuo"])
], targets: [
    .target(name: "FoldCore"),
    .executableTarget(name: "MacbookDuo", dependencies: ["FoldCore"], resources: [.process("Resources")], swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(name: "FoldCoreTests", dependencies: ["FoldCore"]),
    .testTarget(name: "LocalizationTests", dependencies: ["MacbookDuo"])
])
