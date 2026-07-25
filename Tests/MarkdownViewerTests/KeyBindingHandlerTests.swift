//
// KeyBindingHandlerTests.swift
// MarkdownViewer
//
// キーバインドのディスパッチ挙動を固定する特性テスト
// (Command-C/A のパススルー契約が特に重要: コピー機能のデグレ防止)
//

import XCTest
import AppKit
@testable import MarkdownViewer

final class KeyBindingHandlerTests: XCTestCase {

    private var handler: KeyBindingHandler!

    override func setUp() {
        super.setUp()
        handler = KeyBindingHandler()
    }

    /// キーイベントを合成するヘルパー
    private func keyEvent(
        characters: String,
        charactersIgnoringModifiers: String? = nil,
        keyCode: UInt16 = 0,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }

    // MARK: - 文字キーのディスパッチ

    func testCharacterKeyBindingIsDispatched() {
        var called = false
        handler.register(KeyBinding(key: "j")) { _ in
            called = true
            return nil
        }

        let result = handler.handle(keyEvent(characters: "j", keyCode: 38), webView: nil)

        XCTAssertTrue(called)
        XCTAssertNil(result, "処理されたイベントは消費される (nil を返す)")
    }

    func testShiftGCapitalBindingIsDispatched() {
        var called = false
        handler.register(KeyBinding(key: "G")) { _ in
            called = true
            return nil
        }

        // Shift-G: characters は "G"、charactersIgnoringModifiers は "g"
        let event = keyEvent(characters: "G", charactersIgnoringModifiers: "g", keyCode: 5, modifiers: .shift)
        let result = handler.handle(event, webView: nil)

        XCTAssertTrue(called)
        XCTAssertNil(result)
    }

    func testControlModifierBindingIsDispatched() {
        var called = false
        handler.register(KeyBinding(key: "n", modifiers: .control)) { _ in
            called = true
            return nil
        }

        let event = keyEvent(characters: "\u{0E}", charactersIgnoringModifiers: "n", keyCode: 45, modifiers: .control)
        let result = handler.handle(event, webView: nil)

        XCTAssertTrue(called)
        XCTAssertNil(result)
    }

    // MARK: - キーコードのディスパッチ

    func testKeyCodeBindingIsDispatched() {
        var called = false
        handler.register(KeyBinding(keyCode: .downArrow)) { _ in
            called = true
            return nil
        }

        let event = keyEvent(characters: "", charactersIgnoringModifiers: "", keyCode: KeyCode.downArrow.rawValue)
        let result = handler.handle(event, webView: nil)

        XCTAssertTrue(called)
        XCTAssertNil(result)
    }

    func testSpaceWithAndWithoutShiftAreDistinct() {
        var plainCalled = false
        var shiftCalled = false
        handler.register(KeyBinding(keyCode: .space, requiresShift: false)) { _ in
            plainCalled = true
            return nil
        }
        handler.register(KeyBinding(keyCode: .space, requiresShift: true)) { _ in
            shiftCalled = true
            return nil
        }

        _ = handler.handle(keyEvent(characters: " ", keyCode: KeyCode.space.rawValue), webView: nil)
        XCTAssertTrue(plainCalled)
        XCTAssertFalse(shiftCalled)

        plainCalled = false
        _ = handler.handle(keyEvent(characters: " ", keyCode: KeyCode.space.rawValue, modifiers: .shift), webView: nil)
        XCTAssertTrue(shiftCalled)
        XCTAssertFalse(plainCalled)
    }

    /// Space 以外のキーコードは Shift 付きでも Shift なしバインディングにフォールバックする
    func testShiftFallsBackToNonShiftBindingForNonSpaceKeys() {
        var called = false
        handler.register(KeyBinding(keyCode: .downArrow)) { _ in
            called = true
            return nil
        }

        let event = keyEvent(characters: "", charactersIgnoringModifiers: "", keyCode: KeyCode.downArrow.rawValue, modifiers: .shift)
        _ = handler.handle(event, webView: nil)

        XCTAssertTrue(called)
    }

    // MARK: - パススルー契約

    /// Command-C (コピー) は未登録なのでパススルーされ、メニューが処理できる
    func testCommandCIsPassedThrough() {
        registerDefaultLikeBindings()

        let event = keyEvent(characters: "c", keyCode: 8, modifiers: .command)
        let result = handler.handle(event, webView: nil)

        XCTAssertIdentical(result, event, "Command-C は消費せずそのまま返す")
    }

    /// Command-A (全選択) も同様にパススルー
    func testCommandAIsPassedThrough() {
        registerDefaultLikeBindings()

        let event = keyEvent(characters: "a", keyCode: 0, modifiers: .command)
        let result = handler.handle(event, webView: nil)

        XCTAssertIdentical(result, event)
    }

    /// 未登録の文字キーはパススルーされる
    func testUnregisteredKeyIsPassedThrough() {
        let event = keyEvent(characters: "x", keyCode: 7)
        let result = handler.handle(event, webView: nil)
        XCTAssertIdentical(result, event)
    }

    /// 修飾キーが異なれば同じ文字でも別バインディング扱い
    func testSameKeyDifferentModifiersAreDistinct() {
        var called = false
        handler.register(KeyBinding(key: "n", modifiers: .control)) { _ in
            called = true
            return nil
        }

        // 修飾なしの "n" はパススルー
        let event = keyEvent(characters: "n", keyCode: 45)
        let result = handler.handle(event, webView: nil)

        XCTAssertFalse(called)
        XCTAssertIdentical(result, event)
    }

    /// ContentView.registerKeyBindings と同等の文字キーバインディングを登録
    /// (実際の登録内容が変わったらこのテストも合わせて見直す)
    private func registerDefaultLikeBindings() {
        for key in ["j", "k", "G"] {
            handler.register(KeyBinding(key: key)) { _ in nil }
        }
        for key in ["n", "p"] {
            handler.register(KeyBinding(key: key, modifiers: .control)) { _ in nil }
        }
        for key in ["<", ">"] {
            handler.register(KeyBinding(key: key, modifiers: .command)) { _ in nil }
        }
    }
}
