// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MarkdownViewer",
            targets: ["MarkdownViewer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownViewer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "MarkdownViewer",
            exclude: ["Info.plist", "AppIcon.icns"],
            resources: [
                .process("Assets.xcassets"),
                .copy("MarkdownViewer.entitlements")
            ]
        ),
        .testTarget(
            name: "MarkdownViewerTests",
            dependencies: ["MarkdownViewer"],
            path: "Tests/MarkdownViewerTests"
        )
    ]
)

