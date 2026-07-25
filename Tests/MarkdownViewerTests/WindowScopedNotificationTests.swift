//
// WindowScopedNotificationTests.swift
// MarkdownViewer
//
// メニュー通知のウィンドウスコープ判定のテスト
//

import XCTest
import AppKit
@testable import MarkdownViewer

final class WindowScopedNotificationTests: XCTestCase {

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
    }

    func testMatchingWindowIsHandled() {
        let window = makeWindow()
        XCTAssertTrue(WindowScopedNotification.shouldHandle(object: window, in: window))
    }

    func testOtherWindowIsNotHandled() {
        let target = makeWindow()
        let other = makeWindow()
        XCTAssertFalse(WindowScopedNotification.shouldHandle(object: target, in: other))
    }

    /// object が nil (keyWindow が取れない場合のフォールバック) は全ウィンドウで処理
    func testNilObjectFallsBackToBroadcast() {
        XCTAssertTrue(WindowScopedNotification.shouldHandle(object: nil, in: makeWindow()))
        XCTAssertTrue(WindowScopedNotification.shouldHandle(object: nil, in: nil))
    }

    /// NSWindow 以外の object も従来どおりブロードキャスト扱い
    func testNonWindowObjectFallsBackToBroadcast() {
        XCTAssertTrue(WindowScopedNotification.shouldHandle(object: "something", in: makeWindow()))
    }

    /// 受信側の window が nil (未表示など) なら対象ウィンドウ指定の通知は処理しない
    func testTargetedNotificationNotHandledWhenReceiverHasNoWindow() {
        XCTAssertFalse(WindowScopedNotification.shouldHandle(object: makeWindow(), in: nil))
    }
}
