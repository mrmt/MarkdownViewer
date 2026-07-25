//
// HTMLFormatterHeadingIdTests.swift
// MarkdownViewer
//

import XCTest
import Markdown
@testable import MarkdownViewer

final class HTMLFormatterHeadingIdTests: XCTestCase {

    private func render(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        // swift-markdown にも HTMLFormatter があるため、MarkdownViewer側を明示
        var formatter = MarkdownViewer.HTMLFormatter()
        formatter.visit(document)
        return formatter.result
    }

    func testSimpleHeadingGetsId() {
        let html = render("## section")
        XCTAssertTrue(html.contains("<h2 id=\"section\">"), html)
    }

    func testHeadingWithSpaces() {
        let html = render("## Hello World")
        XCTAssertTrue(html.contains("<h2 id=\"hello-world\">"), html)
    }

    func testHeadingWithSymbols() {
        let html = render("## Hello, World!")
        // , と ! は除去、空白は -
        XCTAssertTrue(html.contains("<h2 id=\"hello-world\">"), html)
    }

    func testDuplicateHeadingsGetSuffix() {
        let html = render("""
        ## section

        ## section
        """)
        XCTAssertTrue(html.contains("<h2 id=\"section\">"), html)
        XCTAssertTrue(html.contains("<h2 id=\"section-1\">"), html)
    }

    func testSlugifyTrimsDashes() {
        XCTAssertEqual(MarkdownViewer.HTMLFormatter.slugify("-hello-"), "hello")
        XCTAssertEqual(MarkdownViewer.HTMLFormatter.slugify("!!!hello!!!"), "hello")
    }

    func testSlugifyCollapsesDashes() {
        XCTAssertEqual(MarkdownViewer.HTMLFormatter.slugify("hello   world"), "hello-world")
        XCTAssertEqual(MarkdownViewer.HTMLFormatter.slugify("a--b"), "a-b")
    }

    func testSlugifyPreservesUnicode() {
        // 日本語は alphanumerics (Unicode letter) として残る
        XCTAssertEqual(MarkdownViewer.HTMLFormatter.slugify("セクション"), "セクション")
    }
}
