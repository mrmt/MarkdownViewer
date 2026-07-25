//
// HTMLFormatterChangedLinesTests.swift
// MarkdownViewer
//
// 変更行ハイライト (changedLines → class="changed") の挙動を固定する特性テスト
//

import XCTest
import Markdown
@testable import MarkdownViewer

final class HTMLFormatterChangedLinesTests: XCTestCase {

    private func render(_ markdown: String, changedLines: Set<Int>) -> String {
        let document = Document(parsing: markdown)
        var formatter = MarkdownViewer.HTMLFormatter(changedLines: changedLines)
        formatter.visit(document)
        return formatter.result
    }

    func testNoChangedLinesProducesNoChangedClass() {
        let html = render("# Title\n\nparagraph", changedLines: [])
        XCTAssertFalse(html.contains("changed"), html)
    }

    func testChangedParagraphGetsClass() {
        let html = render("""
        first

        second
        """, changedLines: [3])
        XCTAssertTrue(html.contains("<p>first</p>"), html)
        XCTAssertTrue(html.contains("<p class=\"changed\">second</p>"), html)
    }

    func testChangedHeadingGetsClass() {
        let html = render("# Title", changedLines: [1])
        XCTAssertTrue(html.contains("<h1 id=\"title\" class=\"changed\">"), html)
    }

    /// 複数行ブロックは一部の行が変更されただけでもハイライトされる (isChanged: 交差判定)
    func testMultilineParagraphPartiallyChangedIsHighlighted() {
        let html = render("line one\nline two", changedLines: [2])
        XCTAssertTrue(html.contains("<p class=\"changed\">"), html)
    }

    func testChangedCodeBlockGetsClassOnPre() {
        let html = render("""
        ```swift
        let x = 1
        ```
        """, changedLines: [2])
        XCTAssertTrue(html.contains("<pre class=\"changed\">"), html)
    }

    /// ListItem は全行変更 (isFullyChanged) のときだけハイライトされる
    func testListItemFullyChangedIsHighlighted() {
        let html = render("""
        - one
        - two
        """, changedLines: [2])
        XCTAssertTrue(html.contains("<li>one</li>"), html)
        XCTAssertTrue(html.contains("<li class=\"changed\">two</li>"), html)
    }

    /// 複数行にまたがる ListItem は一部変更ではハイライトされない (fullCheck)
    func testMultilineListItemPartiallyChangedIsNotHighlighted() {
        let html = render("""
        - parent
          - child
        """, changedLines: [2])
        // 親アイテム (1-2行目) は2行目だけの変更なので changed が付かない
        XCTAssertFalse(html.contains("<li class=\"changed\">parent"), html)
        // 子アイテム (2行目のみ) は全行変更なので changed が付く
        XCTAssertTrue(html.contains("<li class=\"changed\">child</li>"), html)
    }

    func testChangedHrGetsClass() {
        let html = render("""
        a

        ---
        """, changedLines: [3])
        XCTAssertTrue(html.contains("<hr class=\"changed\">"), html)
    }

    /// DiffCalculator との統合: 外部エディタでの1行変更 → 該当ブロックのみハイライト
    func testIntegrationWithDiffCalculator() {
        let old = """
        # Title

        original paragraph
        """
        let new = """
        # Title

        modified paragraph
        """
        let changed = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        let html = render(new, changedLines: changed)

        XCTAssertFalse(html.contains("<h1 id=\"title\" class=\"changed\">"), html)
        XCTAssertTrue(html.contains("<p class=\"changed\">modified paragraph</p>"), html)
    }
}
