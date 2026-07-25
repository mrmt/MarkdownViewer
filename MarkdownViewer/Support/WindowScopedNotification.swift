//
// WindowScopedNotification.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import AppKit

/// メニュー操作の通知 (Cmd-R リロード / Cmd-O ファイルを開く) を
/// 対象ウィンドウの ContentView だけが処理するための判定
///
/// 従来は全ウィンドウがブロードキャストを受けて反応していた
/// (Cmd-R で全ウィンドウが一斉リロード、Cmd-O でウィンドウ数ぶんパネルが開く)。
enum WindowScopedNotification {
    /// - Parameters:
    ///   - object: 通知の object (post 側が NSApp.keyWindow を載せる)
    ///   - window: 受信側 View が属するウィンドウ
    /// - Returns: 処理すべきなら true
    ///
    /// object が NSWindow でない場合 (nil 含む) は従来どおり全ウィンドウで処理する
    /// (keyWindow が取れない状況でのフォールバック)
    static func shouldHandle(object: Any?, in window: NSWindow?) -> Bool {
        guard let targetWindow = object as? NSWindow else { return true }
        return targetWindow === window
    }
}
