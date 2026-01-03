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

// MARK: - Key Binding System

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

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var documentManager: DocumentManager
    @State private var markdownContent: String = ""
    @State private var changedLines: Set<Int> = []
    @State private var filePath: String = ""
    @State private var isDragOver = false
    @StateObject private var fileWatcher = FileWatcher()
    @State private var webView: WKWebView?
    @State private var eventMonitor: Any?
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
                MarkdownWebView(markdown: markdownContent, changedLines: changedLines, webView: $webView)
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
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadMarkdownFile"))) { _ in
            reloadMarkdownFile()
        }
        .onAppear {
            // アプリ起動時にファイルパスが指定されていれば読み込む
            if let url = documentManager.fileURL {
                loadMarkdownFile(path: url.path)
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
        // 複数ファイルのドロップに対応
        for (index, provider) in providers.enumerated() {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown"
                else { return }
                
                DispatchQueue.main.async {
                    if index == 0 && self.markdownContent.isEmpty {
                        // 最初のファイルで現在のウィンドウが空の場合は、現在のウィンドウで開く
                        self.loadMarkdownFile(path: url.path)
                    } else {
                        // それ以外は新しいウィンドウで開く
                        NotificationCenter.default.post(name: .openFileInNewWindow, object: url)
                    }
                }
            }
        }
        
        return true
    }
    
    private func loadMarkdownFile(path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            markdownContent = content
            filePath = path
            changedLines = [] // 新規読み込み時は差分なし
            
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
    
    private func registerKeyBindings() {
        // 矢印キー
        keyBindingHandler.register(KeyBinding(keyCode: .downArrow)) { webView in
            MarkdownWebView.scrollDown(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(keyCode: .upArrow)) { webView in
            MarkdownWebView.scrollUp(webView)
            return nil
        }

        // Home/End
        keyBindingHandler.register(KeyBinding(keyCode: .home)) { webView in
            MarkdownWebView.scrollToTop(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(keyCode: .end)) { webView in
            MarkdownWebView.scrollToBottom(webView)
            return nil
        }

        // Page Up/Down
        keyBindingHandler.register(KeyBinding(keyCode: .pageUp)) { webView in
            MarkdownWebView.scrollPageUp(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(keyCode: .pageDown)) { webView in
            MarkdownWebView.scrollPageDown(webView)
            return nil
        }

        // Space (with/without Shift)
        keyBindingHandler.register(KeyBinding(keyCode: .space, requiresShift: false)) { webView in
            MarkdownWebView.scrollPageDown(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(keyCode: .space, requiresShift: true)) { webView in
            MarkdownWebView.scrollPageUp(webView)
            return nil
        }

        // Vim-style navigation
        keyBindingHandler.register(KeyBinding(key: "j")) { webView in
            MarkdownWebView.scrollDown(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(key: "k")) { webView in
            MarkdownWebView.scrollUp(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(key: "G")) { webView in
            MarkdownWebView.scrollToBottom(webView)
            return nil
        }

        // Emacs-style navigation
        keyBindingHandler.register(KeyBinding(key: "n", modifiers: .control)) { webView in
            MarkdownWebView.scrollDown(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(key: "p", modifiers: .control)) { webView in
            MarkdownWebView.scrollUp(webView)
            return nil
        }

        // Command-< / Command->
        keyBindingHandler.register(KeyBinding(key: "<", modifiers: .command)) { webView in
            MarkdownWebView.scrollToTop(webView)
            return nil
        }
        keyBindingHandler.register(KeyBinding(key: ">", modifiers: .command)) { webView in
            MarkdownWebView.scrollToBottom(webView)
            return nil
        }

        // Command-C (コピー) と Command-A (全選択) はメニューに処理させる
        // 注: これらは登録しないことで、デフォルトでパススルーされる
    }

    private func setupKeyEventMonitor() {
        registerKeyBindings()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
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
