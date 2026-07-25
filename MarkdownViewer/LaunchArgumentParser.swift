//
// LaunchArgumentParser.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation

/// コマンドライン引数からオープン対象のファイルURLを抽出する
enum LaunchArgumentParser {
    /// - Parameters:
    ///   - arguments: CommandLine.arguments 相当 (先頭は実行パス)
    ///   - fileExists: ファイル存在チェック (テストで差し替え可能)
    /// - Returns: 存在するファイルのURL一覧 (引数順)
    ///
    /// "-" で始まる引数はフラグとみなし、その次の引数も値としてスキップする
    /// (例: -NSDocumentRevisionsDebugMode YES)
    static func extractFileURLs(
        from arguments: [String],
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> [URL] {
        var urls: [URL] = []
        var skipNext = false
        for arg in arguments.dropFirst() {
            if skipNext {
                skipNext = false
                continue
            }
            if arg.hasPrefix("-") {
                skipNext = true
                continue
            }
            if fileExists(arg) {
                urls.append(URL(fileURLWithPath: arg))
            }
        }
        return urls
    }
}
