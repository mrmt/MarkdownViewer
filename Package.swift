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
        // バージョン固定: branch指定だと上流の変更でビルドが突然壊れるため
        .package(url: "https://github.com/swiftlang/swift-markdown.git", .upToNextMinor(from: "0.7.3"))
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
                .copy("MarkdownViewer.entitlements"),
                .copy("mermaid.min.js")
            ]
        ),
        .testTarget(
            name: "MarkdownViewerTests",
            dependencies: ["MarkdownViewer"],
            path: "Tests/MarkdownViewerTests"
        )
    ]
)

