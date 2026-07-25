//
// KeyBindingHandler.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import AppKit
import WebKit

/// キーコード定義（マジックナンバーを排除）
enum KeyCode: UInt16 {
    case downArrow = 125
    case upArrow = 126
    case home = 115
    case end = 119
    case pageUp = 116
    case pageDown = 121
    case space = 49
}

/// キーバインディング定義
struct KeyBinding: Hashable {
    let key: String?
    let keyCode: KeyCode?
    let modifiers: NSEvent.ModifierFlags
    let requiresShift: Bool

    init(key: String, modifiers: NSEvent.ModifierFlags = [], requiresShift: Bool = false) {
        self.key = key
        self.keyCode = nil
        self.modifiers = modifiers
        self.requiresShift = requiresShift
    }

    init(keyCode: KeyCode, modifiers: NSEvent.ModifierFlags = [], requiresShift: Bool = false) {
        self.key = nil
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.requiresShift = requiresShift
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(keyCode?.rawValue)
        hasher.combine(modifiers.rawValue)
        hasher.combine(requiresShift)
    }

    static func == (lhs: KeyBinding, rhs: KeyBinding) -> Bool {
        lhs.key == rhs.key &&
        lhs.keyCode == rhs.keyCode &&
        lhs.modifiers == rhs.modifiers &&
        lhs.requiresShift == rhs.requiresShift
    }
}

/// キーバインドハンドラ
class KeyBindingHandler {
    typealias Action = (WKWebView?) -> NSEvent?

    private var bindings: [KeyBinding: Action] = [:]

    func register(_ binding: KeyBinding, action: @escaping Action) {
        bindings[binding] = action
    }

    func handle(_ event: NSEvent, webView: WKWebView?) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        let isShiftPressed = event.modifierFlags.contains(.shift)

        // キーコードベースの判定
        if let keyCode = KeyCode(rawValue: event.keyCode) {
            let binding = KeyBinding(keyCode: keyCode, modifiers: modifiers, requiresShift: isShiftPressed)
            if let action = bindings[binding] {
                return action(webView)
            }

            // Shiftを無視したバインディングもチェック（Spaceキー以外）
            if isShiftPressed && keyCode != .space {
                let bindingWithoutShift = KeyBinding(keyCode: keyCode, modifiers: modifiers, requiresShift: false)
                if let action = bindings[bindingWithoutShift] {
                    return action(webView)
                }
            }
        }

        // 文字ベースの判定
        if let characters = event.charactersIgnoringModifiers {
            // Shift-Gのような大文字判定
            if event.characters == "G" && modifiers.isEmpty {
                let binding = KeyBinding(key: "G", modifiers: modifiers)
                if let action = bindings[binding] {
                    return action(webView)
                }
            }

            // 通常の文字キー
            let binding = KeyBinding(key: characters, modifiers: modifiers)
            if let action = bindings[binding] {
                return action(webView)
            }
        }

        return event
    }
}
