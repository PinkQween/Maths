// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Maths",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "Maths",
            targets: ["Maths"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Maths",
            dependencies: [],
            exclude: [
                "units.sh",
                "units.txt",
                "generate-localizations.py",
                "unit-translations.json"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MathsTests",
            dependencies: ["Maths"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
