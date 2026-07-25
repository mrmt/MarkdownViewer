//
// ResourceBundleTests.swift
// MarkdownViewer
//
// バンドルリソース解決のテスト
//

import XCTest
@testable import MarkdownViewer

final class ResourceBundleTests: XCTestCase {

    /// mermaid.min.js がビルド経路 (SwiftPM/Xcode) を問わず解決できること
    func testMermaidScriptIsResolvable() {
        let url = ResourceBundle.current.url(forResource: "mermaid.min", withExtension: "js")
        XCTAssertNotNil(url, "mermaid.min.js がリソースバンドルに見つからない")
    }
}
