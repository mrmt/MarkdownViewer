import XCTest
@testable import MarkdownViewer

final class FileWatcherTests: XCTestCase {

    var fileWatcher: FileWatcher!
    var tempFilePath: String!
    let fileManager = FileManager.default

    override func setUp() {
        super.setUp()
        fileWatcher = FileWatcher()
        
        // 一時ファイルを作成
        let tempDir = NSTemporaryDirectory()
        tempFilePath = (tempDir as NSString).appendingPathComponent("test.md")
        
        // テスト前に古いファイルがあれば削除
        if fileManager.fileExists(atPath: tempFilePath) {
            try? fileManager.removeItem(atPath: tempFilePath)
        }
        
        // 新しいファイルを作成
        fileManager.createFile(atPath: tempFilePath, contents: "Initial content".data(using: .utf8), attributes: nil)
    }

    override func tearDown() {
        // 監視を停止し、リソースを解放
        fileWatcher.stopWatching()
        
        // 一時ファイルを削除
        if fileManager.fileExists(atPath: tempFilePath) {
            try? fileManager.removeItem(atPath: tempFilePath)
        }
        
        fileWatcher = nil
        tempFilePath = nil
        super.tearDown()
    }

    func testFileModificationIsDetected() throws {
        let expectation = self.expectation(description: "File change should be detected")
        
        // ファイル監視を開始
        fileWatcher.startWatching(path: tempFilePath) {
            expectation.fulfill()
        }
        
        // ファイルの初回更新時刻が記録されるのを少し待つ
        Thread.sleep(forTimeInterval: 0.6)

        // ファイルの内容を変更して更新時刻を更新
        try "Updated content".write(toFile: tempFilePath, atomically: true, encoding: .utf8)

        // 期待した変更が検知されるまで最大2秒待つ
        waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testStopWatchingPreventsDetection() throws {
        let expectation = self.expectation(description: "File change should not be detected")
        expectation.isInverted = true // この expectation が fulfill されないことを期待する

        // ファイル監視を開始
        fileWatcher.startWatching(path: tempFilePath) {
            expectation.fulfill()
        }
        
        // 監視をすぐに停止
        fileWatcher.stopWatching()
        
        // ファイルの内容を変更
        try "Updated content".write(toFile: tempFilePath, atomically: true, encoding: .utf8)

        // 変更が検知されないことを確認するために少し待つ
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
//
// DiffCalculatorTests.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import XCTest
@testable import MarkdownViewer

final class DiffCalculatorTests: XCTestCase {

    func testNoChanges() {
        let old = "Line 1\nLine 2"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertTrue(changes.isEmpty, "Should be empty for identical content")
    }

    func testInsertionAtEnd() {
        let old = "Line 1"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2])
    }

    func testInsertionAtStart() {
        let old = "Line 2"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [1])
    }

    func testModification() {
        let old = "Line 1\nLine 2"
        let new = "Line 1\nLine 2 Modified"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        // Modification appears as remove old + insert new at same index
        XCTAssertEqual(changes, [2])
    }

    func testInsertionInMiddle() {
        let old = "Line 1\nLine 3"
        let new = "Line 1\nLine 2\nLine 3"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2])
    }

    func testDeletion() {
        let old = "Line 1\nLine 2"
        let new = "Line 1"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertTrue(changes.isEmpty, "Deletion should not highlight remaining lines")
    }

    func testFullReplacement() {
        let old = "Old"
        let new = "New"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [1])
    }

    func testMultipleInsertions() {
        let old = "A\nC"
        let new = "A\nB\nC\nD"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2, 4])
    }
}

//
// HTMLFormatterLinkTests.swift
// MarkdownViewer
//
// リンク解決のテスト
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

//
// HTMLFormatterHeadingIdTests.swift
// 見出しに slug id を付与するテスト (ページ内アンカー用)
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
