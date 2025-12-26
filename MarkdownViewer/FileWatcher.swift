//
// FileWatcher.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation
import Combine

/// タイマーベースのファイル監視クラス
///
/// 指定されたファイルパスを定期的にチェックし、変更が検出されたら
/// コールバックを実行します。ObservableObjectに準拠しているため、
/// SwiftUIのViewから直接使用できます。
class FileWatcher: ObservableObject {
    private var timer: Timer?
    private var filePath: String?
    private var onChange: (() -> Void)?
    private var lastModificationDate: Date?

    /// ファイル監視を開始
    /// - Parameters:
    ///   - path: 監視するファイルのパス
    ///   - onChange: ファイルが変更されたときに実行されるコールバック
    func startWatching(path: String, onChange: @escaping () -> Void) {
        stopWatching()

        self.filePath = path
        self.onChange = onChange

        // 現在の最終更新時刻を取得
        updateLastModificationDate()

        // 0.5秒ごとにファイルの変更をチェック
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkFileAndNotify()
        }
    }

    /// 最終更新日時を更新
    private func updateLastModificationDate() {
        guard let filePath = filePath else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            lastModificationDate = attributes[.modificationDate] as? Date
        } catch {
            // エラーは無視（ファイルが一時的にアクセスできない可能性がある）
        }
    }

    /// ファイルをチェックして変更があれば通知
    private func checkFileAndNotify() {
        guard let filePath = filePath,
              FileManager.default.fileExists(atPath: filePath) else {
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let currentModificationDate = attributes[.modificationDate] as? Date

            if let lastDate = lastModificationDate,
               let currentDate = currentModificationDate,
               currentDate > lastDate {
                lastModificationDate = currentDate

                // メインスレッドで更新を実行
                DispatchQueue.main.async {
                    self.onChange?()
                }
            }
        } catch {
            // エラーは無視
        }
    }

    /// ファイル監視を停止
    func stopWatching() {
        timer?.invalidate()
        timer = nil
        filePath = nil
        onChange = nil
        lastModificationDate = nil
    }

    deinit {
        stopWatching()
    }
}
