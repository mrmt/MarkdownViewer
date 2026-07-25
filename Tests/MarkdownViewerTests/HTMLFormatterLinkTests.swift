//
// HTMLFormatterLinkTests.swift
// MarkdownViewer
//

import XCTest
import Markdown
@testable import MarkdownViewer

final class HTMLFormatterLinkTests: XCTestCase {

    private func render(_ markdown: String, baseFileURL: URL? = nil) -> String {
        let document = Document(parsing: markdown)
        var formatter = MarkdownViewer.HTMLFormatter(changedLines: [], baseFileURL: baseFileURL)
        formatter.visit(document)
        return formatter.result
    }

    func testHttpsLinkPreserved() {
        let html = render("[link](https://example.com/path)", baseFileURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(html.contains("href=\"https://example.com/path\""), html)
    }

    func testRelativeLinkResolvedAgainstBaseURL() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](sub/foo.md)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/sub/foo.md\""), html)
    }

    func testDotSlashRelativeLinkResolved() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](./foo.md)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/foo.md\""), html)
    }

    func testParentRelativeLinkResolved() {
        let base = URL(fileURLWithPath: "/tmp/docs/sub/")
        let html = render("[link](../foo.md)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/foo.md\""), html)
    }

    func testAbsolutePathResolvedAsFileURL() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](/abs/foo.md)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"file:///abs/foo.md\""), html)
    }

    func testFragmentOnlyLinkPreserved() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](#section)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"#section\""), html)
    }

    func testMailtoLinkPreserved() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[mail](mailto:foo@example.com)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"mailto:foo@example.com\""), html)
    }

    func testRelativeLinkUnchangedWhenBaseURLMissing() {
        let html = render("[link](./foo.md)", baseFileURL: nil)
        XCTAssertTrue(html.contains("href=\"./foo.md\""), html)
    }

    func testPercentEncodedPathResolved() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](foo%20bar.md)", baseFileURL: base)
        // space should be URL-encoded as %20 in the absolute URL
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/foo%20bar.md\""), html)
    }

    func testRelativeLinkWithFragmentPreservesFragment() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](other.md#section)", baseFileURL: base)
        // fragment は # のまま保持され、%23 にエンコードされない
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/other.md#section\""), html)
    }

    func testRelativeLinkWithFragmentHasCorrectPathExtension() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](other.md#section)", baseFileURL: base)

        // HTML から href を取り出して URL にパースし、pathExtension が "md" であることを確認
        // (openLocalMarkdownFile が fragment 付き URL を弾かないことの検証)
        let pattern = #"href=\"([^\"]+)\""#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let match = regex.firstMatch(in: html, range: range)
        XCTAssertNotNil(match)
        let hrefRange = Range(match!.range(at: 1), in: html)!
        let href = String(html[hrefRange])

        let url = URL(string: href)!
        XCTAssertEqual(url.pathExtension.lowercased(), "md")
        XCTAssertEqual(url.fragment, "section")
        XCTAssertEqual(url.path, "/tmp/docs/other.md")
    }

    func testLinkWithQueryPreserved() {
        let base = URL(fileURLWithPath: "/tmp/docs/")
        let html = render("[link](other.md?v=1)", baseFileURL: base)
        XCTAssertTrue(html.contains("href=\"file:///tmp/docs/other.md?v=1\""), html)
    }
}
