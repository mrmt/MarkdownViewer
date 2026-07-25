//
// HTMLFormatterBasicTests.swift
// MarkdownViewer
//
// HTMLFormatter の基本要素の出力を固定する特性テスト
// (リファクタリング時のデグレ検知が目的)
//

import XCTest
import Markdown
@testable import MarkdownViewer

final class HTMLFormatterBasicTests: XCTestCase {

    private func render(_ markdown: String, changedLines: Set<Int> = []) -> String {
        let document = Document(parsing: markdown)
        var formatter = MarkdownViewer.HTMLFormatter(changedLines: changedLines)
        formatter.visit(document)
        return formatter.result
    }

    // MARK: - 見出し・段落・インライン要素

    func testHeadingLevels() {
        XCTAssertTrue(render("# H1").contains("<h1 id=\"h1\">H1</h1>"))
        XCTAssertTrue(render("### H3").contains("<h3 id=\"h3\">H3</h3>"))
        XCTAssertTrue(render("###### H6").contains("<h6 id=\"h6\">H6</h6>"))
    }

    func testParagraph() {
        XCTAssertEqual(render("hello world"), "<p>hello world</p>")
    }

    func testEmphasisAndStrong() {
        XCTAssertEqual(render("*em* and **strong**"), "<p><em>em</em> and <strong>strong</strong></p>")
    }

    func testInlineCodeIsEscaped() {
        XCTAssertEqual(render("`<tag>`"), "<p><code>&lt;tag&gt;</code></p>")
    }

    func testTextIsHTMLEscaped() {
        XCTAssertEqual(render("a < b & c"), "<p>a &lt; b &amp; c</p>")
    }

    func testSoftBreakBecomesSpace() {
        XCTAssertEqual(render("line one\nline two"), "<p>line one line two</p>")
    }

    // MARK: - コードブロック

    func testCodeBlockWithLanguage() {
        let html = render("""
        ```swift
        let x = 1
        ```
        """)
        XCTAssertEqual(html, "<pre><code class=\"language-swift\">let x = 1\n</code></pre>")
    }

    func testCodeBlockWithoutLanguage() {
        let html = render("""
        ```
        plain
        ```
        """)
        XCTAssertEqual(html, "<pre><code>plain\n</code></pre>")
    }

    func testCodeBlockContentIsEscaped() {
        let html = render("""
        ```
        <script>alert(1)</script>
        ```
        """)
        XCTAssertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"), html)
    }

    // MARK: - Mermaid

    func testMermaidBlockProducesDivAndSetsFlag() {
        let document = Document(parsing: """
        ```mermaid
        graph TD; A-->B;
        ```
        """)
        var formatter = MarkdownViewer.HTMLFormatter()
        formatter.visit(document)

        XCTAssertTrue(formatter.hasMermaid)
        XCTAssertTrue(formatter.result.contains("<div class=\"mermaid\">"), formatter.result)
        XCTAssertTrue(formatter.result.contains("graph TD; A--&gt;B;"), formatter.result)
    }

    func testNonMermaidBlockDoesNotSetFlag() {
        let document = Document(parsing: """
        ```swift
        let x = 1
        ```
        """)
        var formatter = MarkdownViewer.HTMLFormatter()
        formatter.visit(document)
        XCTAssertFalse(formatter.hasMermaid)
    }

    // MARK: - blockquote / hr / 改行

    func testBlockquote() {
        XCTAssertEqual(render("> quoted"), "<blockquote><p>quoted</p></blockquote>")
    }

    func testThematicBreak() {
        let html = render("""
        a

        ---

        b
        """)
        XCTAssertTrue(html.contains("<hr>"), html)
    }

    // MARK: - リスト

    func testUnorderedList() {
        let html = render("""
        - one
        - two
        """)
        XCTAssertEqual(html, "<ul><li>one</li><li>two</li></ul>")
    }

    func testOrderedList() {
        let html = render("""
        1. first
        2. second
        """)
        XCTAssertEqual(html, "<ol><li>first</li><li>second</li></ol>")
    }

    func testNestedList() {
        let html = render("""
        - parent
          - child
        """)
        XCTAssertEqual(html, "<ul><li>parent<ul><li>child</li></ul></li></ul>")
    }

    /// リスト項目内の段落は <p> タグを省略する (現行仕様)
    func testListItemParagraphOmitsPTag() {
        let html = render("- item text")
        XCTAssertFalse(html.contains("<p>"), html)
    }

    // MARK: - テーブル

    func testTableStructure() {
        let html = render("""
        | A | B |
        |---|---|
        | 1 | 2 |
        """)
        XCTAssertTrue(html.contains("<table>"), html)
        XCTAssertTrue(html.contains("<thead>"), html)
        XCTAssertTrue(html.contains("<tbody>"), html)
        XCTAssertTrue(html.contains("</table>"), html)
    }

    /// ヘッダ行のセルは <th>、ボディ行のセルは <td>
    func testTableHeaderCellsAreTh() {
        let html = render("""
        | A | B |
        |---|---|
        | 1 | 2 |
        """)
        XCTAssertTrue(html.contains("<thead><tr><th>A</th><th>B</th></tr></thead>"), html)
    }

    func testTableBodyCellsAreTd() {
        let html = render("""
        | A | B |
        |---|---|
        | 1 | 2 |
        """)
        XCTAssertTrue(html.contains("<td>1</td><td>2</td>"), html)
    }

    /// colspan はヘッダ判定ではなく属性として出力される
    func testTableCellColspanBecomesAttribute() {
        let html = render("""
        | A | B |
        |---|---|
        | span ||
        """)
        XCTAssertTrue(html.contains("<td colspan=\"2\">span</td>"), html)
    }
}

// MARK: - String.htmlEscaped

final class StringHTMLEscapeTests: XCTestCase {

    func testEscapesAllSpecialCharacters() {
        XCTAssertEqual("&".htmlEscaped, "&amp;")
        XCTAssertEqual("<".htmlEscaped, "&lt;")
        XCTAssertEqual(">".htmlEscaped, "&gt;")
        XCTAssertEqual("\"".htmlEscaped, "&quot;")
        XCTAssertEqual("'".htmlEscaped, "&#39;")
    }

    /// & のエスケープが最初に行われるため、二重エスケープが起きない
    func testNoDoubleEscaping() {
        XCTAssertEqual("<b>".htmlEscaped, "&lt;b&gt;")
        XCTAssertEqual("&lt;".htmlEscaped, "&amp;lt;")
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual("日本語 text 123".htmlEscaped, "日本語 text 123")
    }
}
