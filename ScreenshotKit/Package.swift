// swift-tools-version: 5.9
import PackageDescription

// ScreenshotKit — the shared, on-device data layer + design system.
//
// This package is imported by BOTH the main app and the Share Extension so
// they speak to the same SwiftData schema and the same store file (which lives
// in a shared App Group container). It is the "shared on-device data layer".
//
// It builds standalone with `swift build`, which lets us compile-verify the
// models and design tokens without full Xcode.
let package = Package(
    name: "ScreenshotKit",
    platforms: [
        .iOS(.v17),   // SwiftData requires iOS 17+
        .macOS(.v14), // so the package also compiles on macOS for CI/verification
    ],
    products: [
        .library(name: "ScreenshotKit", targets: ["ScreenshotKit"]),
    ],
    targets: [
        .target(name: "ScreenshotKit"),
        .testTarget(name: "ScreenshotKitTests", dependencies: ["ScreenshotKit"]),
    ]
)
