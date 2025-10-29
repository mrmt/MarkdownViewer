//
// ContentView.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI

// ファイル監視クラス（タイマーベース）
class FileWatcher: ObservableObject {
    private var timer: Timer?
    private var filePath: String?
    private var onChange: (() -> Void)?
    private var lastModificationDate: Date?
    
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
    
    private func updateLastModificationDate() {
        guard let filePath = filePath else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            lastModificationDate = attributes[.modificationDate] as? Date
        } catch {
            // エラーは無視（ファイルが一時的にアクセスできない可能性がある）
        }
    }
    
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

struct ContentView: View {
    @ObservedObject var documentManager: DocumentManager
    @State private var markdownContent: String = ""
    @State private var filePath: String = ""
    @State private var isDragOver = false
    @StateObject private var fileWatcher = FileWatcher()
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            if !filePath.isEmpty {
                HStack {
                    Text(URL(fileURLWithPath: filePath).lastPathComponent)
                        .font(.headline)
                        .padding(.leading)
                    Spacer()
                    Text(filePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }
            
            // Markdownビューア
            if markdownContent.isEmpty {
                // ドラッグ&ドロップエリア
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Markdownファイルをドラッグ&ドロップ")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("または引数でファイルパスを指定してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [10])
                        )
                        .padding(40)
                )
            } else {
                MarkdownWebView(markdown: markdownContent)
            }
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: documentManager.fileURL) { newURL in
            if let url = newURL {
                loadMarkdownFile(path: url.path)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMarkdownFile"))) { notification in
            if let userInfo = notification.userInfo,
               let path = userInfo["filePath"] as? String {
                loadMarkdownFile(path: path)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadMarkdownFile"))) { _ in
            reloadMarkdownFile()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown"
            else { return }
            
            DispatchQueue.main.async {
                loadMarkdownFile(path: url.path)
            }
        }
        
        return true
    }
    
    private func loadMarkdownFile(path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            markdownContent = content
            filePath = path
            
            // ファイルの変更を監視開始
            fileWatcher.startWatching(path: path) { [self] in
                self.reloadMarkdownFile()
            }
        } catch {
            print("ファイルの読み込みに失敗: \(error)")
        }
    }
    
    private func reloadMarkdownFile() {
        guard !filePath.isEmpty else { return }
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            markdownContent = content
        } catch {
            print("ファイルの再読み込みに失敗: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(documentManager: DocumentManager.shared)
    }
}
