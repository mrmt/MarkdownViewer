//
// FrontmatterRendererTests.swift
// MarkdownViewer
//

import XCTest
@testable import MarkdownViewer

final class FrontmatterRendererTests: XCTestCase {

    func testSplitExtractsFrontmatterAtTop() {
        let markdown = """
        ---
        title: Example
        tags:
          - swift
        ---
        # Heading
        """

        let parts = MarkdownViewer.FrontmatterRenderer.split(markdown)

        XCTAssertEqual(parts.frontmatter, "---\ntitle: Example\ntags:\n  - swift\n---\n")
        XCTAssertEqual(parts.body, "# Heading")
    }

    func testSplitSupportsDotsClosingDelimiter() {
        let markdown = """
        ---
        title: Example
        ...
        Body
        """

        let parts = MarkdownViewer.FrontmatterRenderer.split(markdown)

        XCTAssertEqual(parts.frontmatter, "---\ntitle: Example\n...\n")
        XCTAssertEqual(parts.body, "Body")
    }

    func testSplitIgnoresHorizontalRuleOutsideFileStart() {
        let markdown = """
        # Heading
        ---
        Body
        """

        let parts = MarkdownViewer.FrontmatterRenderer.split(markdown)

        XCTAssertNil(parts.frontmatter)
        XCTAssertEqual(parts.body, markdown)
    }

    func testFrontmatterHTMLUsesDedicatedClassAndEscapesContent() {
        let html = MarkdownViewer.FrontmatterRenderer.html(for: """
        ---
        title: <Example>
        ---
        """)

        XCTAssertTrue(html.contains("<pre class=\"frontmatter\">"), html)
        XCTAssertTrue(html.contains("title: &lt;Example&gt;"), html)
        XCTAssertTrue(html.contains("---"), html)
    }
}

//
// HTMLFormatterLinkTests.swift
// MarkdownViewer
//
// リンク解決のテスト
//

import Markdown
