//
// DefaultKeyBindings.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import WebKit

/// アプリ標準のキーバインディング定義 (テーブル駆動)
///
/// 注意: Command-C (コピー) と Command-A (全選択) は意図的に登録しない。
/// 未登録キーはパススルーされ、メニュー側で処理される (KeyBindingHandlerTests で担保)。
enum DefaultKeyBindings {

    /// スクロール操作の種類
    private enum ScrollAction {
        case lineDown, lineUp, pageDown, pageUp, toTop, toBottom

        func perform(_ webView: WKWebView?) {
            switch self {
            case .lineDown: MarkdownWebView.scrollDown(webView)
            case .lineUp: MarkdownWebView.scrollUp(webView)
            case .pageDown: MarkdownWebView.scrollPageDown(webView)
            case .pageUp: MarkdownWebView.scrollPageUp(webView)
            case .toTop: MarkdownWebView.scrollToTop(webView)
            case .toBottom: MarkdownWebView.scrollToBottom(webView)
            }
        }
    }

    /// バインディング一覧
    private static let table: [(KeyBinding, ScrollAction)] = [
        // 矢印キー
        (KeyBinding(keyCode: .downArrow), .lineDown),
        (KeyBinding(keyCode: .upArrow), .lineUp),
        // Home/End
        (KeyBinding(keyCode: .home), .toTop),
        (KeyBinding(keyCode: .end), .toBottom),
        // Page Up/Down
        (KeyBinding(keyCode: .pageUp), .pageUp),
        (KeyBinding(keyCode: .pageDown), .pageDown),
        // Space (Shiftの有無で方向が変わる)
        (KeyBinding(keyCode: .space, requiresShift: false), .pageDown),
        (KeyBinding(keyCode: .space, requiresShift: true), .pageUp),
        // Vim風
        (KeyBinding(key: "j"), .lineDown),
        (KeyBinding(key: "k"), .lineUp),
        (KeyBinding(key: "G"), .toBottom),
        // Emacs風
        (KeyBinding(key: "n", modifiers: .control), .lineDown),
        (KeyBinding(key: "p", modifiers: .control), .lineUp),
        // Command-< / Command->
        (KeyBinding(key: "<", modifiers: .command), .toTop),
        (KeyBinding(key: ">", modifiers: .command), .toBottom)
    ]

    /// 標準バインディングをハンドラに登録する
    static func register(into handler: KeyBindingHandler) {
        for (binding, action) in table {
            handler.register(binding) { webView in
                action.perform(webView)
                return nil
            }
        }
    }
}
