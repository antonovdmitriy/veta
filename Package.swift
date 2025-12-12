// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Veta",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VetaCore",
            targets: ["VetaCore"]
        )
    ],
    dependencies: [
        // Markdown rendering
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.3.0"),

        // Keychain access
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),

        // ZIP archive support
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "VetaCore",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Veta/Shared"
        ),
        .testTarget(
            name: "VetaCoreTests",
            dependencies: ["VetaCore"],
            path: "Veta/Tests"
        )
    ]
)
