//
// FileWatcherTests.swift
// MarkdownViewer
//

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

        // 監視間隔を短くしてテストを高速化 (本番デフォルトは0.5秒)
        fileWatcher.startWatching(path: tempFilePath, interval: 0.05) {
            expectation.fulfill()
        }

        // mtime が確実に前回より新しくなるよう少しだけ待つ
        Thread.sleep(forTimeInterval: 0.1)

        // ファイルの内容を変更して更新時刻を更新
        try "Updated content".write(toFile: tempFilePath, atomically: true, encoding: .utf8)

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testStopWatchingPreventsDetection() throws {
        let expectation = self.expectation(description: "File change should not be detected")
        expectation.isInverted = true // この expectation が fulfill されないことを期待する

        fileWatcher.startWatching(path: tempFilePath, interval: 0.05) {
            expectation.fulfill()
        }

        // 監視をすぐに停止
        fileWatcher.stopWatching()

        // ファイルの内容を変更
        try "Updated content".write(toFile: tempFilePath, atomically: true, encoding: .utf8)

        // 変更が検知されないことを確認するために少し待つ
        waitForExpectations(timeout: 0.5, handler: nil)
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
