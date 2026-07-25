//
// DropTargetPlanner.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation

/// ドロップされたファイルの振り分け計画
///
/// 従来は各ファイルの非同期ロード完了順に依存していたため、
/// 完了順が前後すると「どのファイルが現在のウィンドウで開くか」が不定だった。
/// 全URLが揃ってから決定的に振り分ける。
enum DropTargetPlanner {
    struct Plan: Equatable {
        /// 現在のウィンドウで開くファイル (nil なら現在のウィンドウでは開かない)
        var openInCurrentWindow: URL?
        /// 新しいウィンドウで開くファイル (ドロップ順)
        var openInNewWindows: [URL]
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown"]

    /// - Parameters:
    ///   - urls: ドロップされたURL (nil = 解決失敗) をドロップ順で
    ///   - isCurrentWindowEmpty: 現在のウィンドウが空 (未読み込み) かどうか
    static func plan(urls: [URL?], isCurrentWindowEmpty: Bool) -> Plan {
        let markdownURLs = urls
            .compactMap { $0 }
            .filter { markdownExtensions.contains($0.pathExtension.lowercased()) }

        guard let first = markdownURLs.first else {
            return Plan(openInCurrentWindow: nil, openInNewWindows: [])
        }

        if isCurrentWindowEmpty {
            return Plan(openInCurrentWindow: first, openInNewWindows: Array(markdownURLs.dropFirst()))
        }
        return Plan(openInCurrentWindow: nil, openInNewWindows: markdownURLs)
    }
}
