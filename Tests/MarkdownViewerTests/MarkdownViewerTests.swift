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
