//
// DropTargetPlannerTests.swift
// MarkdownViewer
//
// ドロップファイル振り分けロジックのテスト
//

import XCTest
@testable import MarkdownViewer

final class DropTargetPlannerTests: XCTestCase {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testSingleFileIntoEmptyWindow() {
        let plan = DropTargetPlanner.plan(urls: [url("a.md")], isCurrentWindowEmpty: true)
        XCTAssertEqual(plan.openInCurrentWindow, url("a.md"))
        XCTAssertTrue(plan.openInNewWindows.isEmpty)
    }

    func testSingleFileIntoOccupiedWindowOpensNewWindow() {
        let plan = DropTargetPlanner.plan(urls: [url("a.md")], isCurrentWindowEmpty: false)
        XCTAssertNil(plan.openInCurrentWindow)
        XCTAssertEqual(plan.openInNewWindows, [url("a.md")])
    }

    /// 複数ファイル: 最初の1つが現ウィンドウ、残りは新規ウィンドウ (ドロップ順を維持)
    func testMultipleFilesIntoEmptyWindow() {
        let plan = DropTargetPlanner.plan(
            urls: [url("a.md"), url("b.md"), url("c.markdown")],
            isCurrentWindowEmpty: true
        )
        XCTAssertEqual(plan.openInCurrentWindow, url("a.md"))
        XCTAssertEqual(plan.openInNewWindows, [url("b.md"), url("c.markdown")])
    }

    func testNonMarkdownFilesAreFiltered() {
        let plan = DropTargetPlanner.plan(
            urls: [url("image.png"), url("a.md")],
            isCurrentWindowEmpty: true
        )
        XCTAssertEqual(plan.openInCurrentWindow, url("a.md"))
        XCTAssertTrue(plan.openInNewWindows.isEmpty)
    }

    /// 解決に失敗した (nil) エントリは無視され、順序は保たれる
    func testFailedResolutionsAreIgnored() {
        let plan = DropTargetPlanner.plan(
            urls: [nil, url("a.md"), nil, url("b.md")],
            isCurrentWindowEmpty: true
        )
        XCTAssertEqual(plan.openInCurrentWindow, url("a.md"))
        XCTAssertEqual(plan.openInNewWindows, [url("b.md")])
    }

    func testCaseInsensitiveExtension() {
        let plan = DropTargetPlanner.plan(urls: [url("A.MD")], isCurrentWindowEmpty: true)
        XCTAssertEqual(plan.openInCurrentWindow, url("A.MD"))
    }

    func testNoMarkdownFilesYieldsEmptyPlan() {
        let plan = DropTargetPlanner.plan(urls: [url("a.txt"), nil], isCurrentWindowEmpty: true)
        XCTAssertNil(plan.openInCurrentWindow)
        XCTAssertTrue(plan.openInNewWindows.isEmpty)
    }
}
