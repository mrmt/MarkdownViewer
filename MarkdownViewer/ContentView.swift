//
// ContentView.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var documentManager: DocumentManager
    @State private var markdownContent: String = ""
    @State private var changedLines: Set<Int> = []
    @State private var filePath: String = ""
    @State private var initialFragment: String?
    @State private var isDragOver = false
    @StateObject private var fileWatcher = FileWatcher()
    @State private var webView: WKWebView?
    @State private var eventMonitor: Any?
    @State private var hostWindow: NSWindow?
    private let keyBindingHandler = KeyBindingHandler()

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
                MarkdownWebView(
                    markdown: markdownContent,
                    changedLines: changedLines,
                    fileDirectoryURL: filePath.isEmpty ? nil : URL(fileURLWithPath: filePath).deletingLastPathComponent(),
                    initialFragment: $initialFragment,
                    webView: $webView
                )
            }
        }
        .background(WindowAccessor(window: $hostWindow))
        .onDrop(of: ["public.file-url"], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: documentManager.fileURL) { newURL in
            if let url = newURL {
                loadMarkdownFile(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { notification in
            guard WindowScopedNotification.shouldHandle(object: notification.object, in: hostWindow) else { return }
            openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMarkdownFile)) { notification in
            guard WindowScopedNotification.shouldHandle(object: notification.object, in: hostWindow) else { return }
            reloadMarkdownFile()
        }
        .onAppear {
            // アプリ起動時にファイルパスが指定されていれば読み込む
            if let url = documentManager.fileURL {
                loadMarkdownFile(url: url)
                // documentManager の URL をクリアして、次回以降の onChange を正しく検知
                DispatchQueue.main.async {
                    documentManager.fileURL = nil
                }
            }
            setupKeyEventMonitor()
        }
        .onDisappear {
            removeKeyEventMonitor()
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true  // 複数ファイルを選択可能にする
        panel.allowedContentTypes = [UTType.text]

        if panel.runModal() == .OK {
            for url in panel.urls {
                if markdownContent.isEmpty {
                    // 現在のウィンドウが空の場合は、現在のウィンドウで開く
                    loadMarkdownFile(path: url.path)
                } else {
                    // それ以外は新しいウィンドウで開く
                    NotificationCenter.default.post(name: .openFileInNewWindow, object: url)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 各providerのURL解決は非同期で完了順が不定なため、
        // 全て揃ってから DropTargetPlanner で決定的に振り分ける
        let group = DispatchGroup()
        var urls = [URL?](repeating: nil, count: providers.count)

        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                urls[index] = url
            }
        }

        group.notify(queue: .main) {
            let plan = DropTargetPlanner.plan(urls: urls, isCurrentWindowEmpty: self.markdownContent.isEmpty)
            if let url = plan.openInCurrentWindow {
                self.loadMarkdownFile(path: url.path)
            }
            for url in plan.openInNewWindows {
                NotificationCenter.default.post(name: .openFileInNewWindow, object: url)
            }
        }

        return true
    }

    /// fragment 付き URL を渡すと、ロード完了時に該当見出しへスクロールする
    private func loadMarkdownFile(url: URL) {
        loadMarkdownFile(path: url.path, fragment: url.fragment)
    }

    private func loadMarkdownFile(path: String, fragment: String? = nil) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            markdownContent = content
            filePath = path
            changedLines = [] // 新規読み込み時は差分なし
            initialFragment = fragment

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

            // 差分計算
            let changes = DiffCalculator.calculateChangedLines(oldContent: markdownContent, newContent: content)
            changedLines = changes

            markdownContent = content
        } catch {
            print("ファイルの再読み込みに失敗: \(error)")
        }
    }

    private func setupKeyEventMonitor() {
        DefaultKeyBindings.register(into: keyBindingHandler)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // このモニタはアプリ全体に効くため、ウィンドウごとに登録されると多重処理になる。
            // 自ウィンドウのイベント以外はパススルーし、該当ウィンドウのモニタに委ねる
            guard event.window === hostWindow else { return event }
            return keyBindingHandler.handle(event, webView: webView)
        }
    }

    private func removeKeyEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(documentManager: DocumentManager())
    }
}
