//
// LaunchArgumentParserTests.swift
// MarkdownViewer
//
// コマンドライン引数パースのテスト
//

import XCTest
@testable import MarkdownViewer

final class LaunchArgumentParserTests: XCTestCase {

    private func parse(_ arguments: [String], existing: Set<String>) -> [String] {
        LaunchArgumentParser.extractFileURLs(from: arguments) { existing.contains($0) }
            .map(\.path)
    }

    func testExtractsExistingFile() {
        let urls = parse(["/app", "/tmp/a.md"], existing: ["/tmp/a.md"])
        XCTAssertEqual(urls, ["/tmp/a.md"])
    }

    func testIgnoresNonExistentFile() {
        let urls = parse(["/app", "/tmp/missing.md"], existing: [])
        XCTAssertTrue(urls.isEmpty)
    }

    func testMultipleFilesPreserveOrder() {
        let urls = parse(["/app", "/tmp/a.md", "/tmp/b.md"], existing: ["/tmp/a.md", "/tmp/b.md"])
        XCTAssertEqual(urls, ["/tmp/a.md", "/tmp/b.md"])
    }

    /// "-flag value" 形式はフラグと値の両方をスキップする
    func testFlagAndItsValueAreSkipped() {
        let urls = parse(
            ["/app", "-NSDocumentRevisionsDebugMode", "YES", "/tmp/a.md"],
            existing: ["/tmp/a.md", "YES"]
        )
        XCTAssertEqual(urls, ["/tmp/a.md"])
    }

    func testExecutablePathIsIgnored() {
        let urls = parse(["/tmp/a.md"], existing: ["/tmp/a.md"])
        XCTAssertTrue(urls.isEmpty, "先頭の実行パスは対象外")
    }

    func testEmptyArguments() {
        XCTAssertTrue(parse([], existing: []).isEmpty)
    }
}
