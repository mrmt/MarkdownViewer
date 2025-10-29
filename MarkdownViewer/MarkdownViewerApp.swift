//
// MarkdownViewerApp.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI

// ファイル状態を管理するObservableObject
class DocumentManager: ObservableObject {
    @Published var fileURL: URL?
    
    static let shared = DocumentManager()
    private init() {}
}

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var documentManager = DocumentManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(documentManager: documentManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("表示") {
                Button("リロード") {
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadMarkdownFile"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .handlesExternalEvents(matching: [])
        .defaultSize(width: 800, height: 600)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingFileURL: URL?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // ファイルを開くイベントを受け取る準備
        // このメソッドは application(_:open:) より前に呼ばれる
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // ウィンドウがない場合は新しいウィンドウを開く
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // アプリをアクティブにする
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // 保留中のファイルまたはコマンドライン引数からファイルを取得
        var fileToOpen: URL? = pendingFileURL
        
        // コマンドライン引数をチェック（システム引数は無視）
        if fileToOpen == nil {
            let args = CommandLine.arguments
            if args.count > 1 {
                // システム引数とその値を無視
                var skipNext = false
                var filePaths: [String] = []
                for arg in args.dropFirst() {
                    if skipNext {
                        skipNext = false
                        continue
                    }
                    if arg.hasPrefix("-") {
                        // 次の引数もスキップ（-XXX YYYのパターン）
                        skipNext = true
                        continue
                    }
                    // ファイルとして存在するかチェック
                    if FileManager.default.fileExists(atPath: arg) {
                        filePaths.append(arg)
                    }
                }
                
                if let filePath = filePaths.first {
                    fileToOpen = URL(fileURLWithPath: filePath)
                }
            }
        }
        
        // ウィンドウが存在しない場合、必ず作成
        if NSApplication.shared.windows.isEmpty {
            createWindow()
        }
        
        // ファイルを開く必要がある場合、ウィンドウが作成されるまで待つ
        if let url = fileToOpen {
            waitForWindowAndOpenFile(url: url)
        }
    }
    
    private func waitForWindowAndOpenFile(url: URL, attempts: Int = 0) {
        if !NSApplication.shared.windows.isEmpty {
            // ウィンドウが存在する
            ensureWindowVisible()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.openFile(url: url)
                self.pendingFileURL = nil
            }
        } else if attempts < 20 {
            // まだウィンドウがない場合、0.1秒後に再試行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.waitForWindowAndOpenFile(url: url, attempts: attempts + 1)
            }
        } else {
            // タイムアウト：ウィンドウが作成されなかった
            self.openFile(url: url)
            self.pendingFileURL = nil
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // ファイルを開く（Finderからダブルクリックやopenコマンドで開いた場合）
        guard let url = urls.first else { return }
        
        // 保留中のファイルとして保存（applicationDidFinishLaunchingで処理）
        pendingFileURL = url
        
        // ウィンドウがない場合は手動で作成
        if NSApplication.shared.windows.isEmpty {
            createWindow()
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // 旧形式のメソッドも残しておく（互換性のため）
        let url = URL(fileURLWithPath: filename)
        
        // 保留中のファイルとして保存
        pendingFileURL = url
        
        // ウィンドウがない場合は手動で作成
        if NSApplication.shared.windows.isEmpty {
            createWindow()
        }
        
        // falseを返すことで、デフォルトのドキュメントベースの動作を防ぐ
        return false
    }
    
    private func createWindow() {
        // SwiftUIビューを作成
        let contentView = ContentView(documentManager: DocumentManager.shared)
            .frame(minWidth: 800, minHeight: 600)
        
        // NSWindowを作成
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "MarkdownViewer"
        window.makeKeyAndOrderFront(nil)
    }
    
    private func ensureWindowVisible() {
        // メインウィンドウを前面に表示
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
    
    private func openFile(url: URL) {
        DispatchQueue.main.async {
            DocumentManager.shared.fileURL = url
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // 起動時に常に新しいウィンドウを開く
        return true
    }
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // ウィンドウを開く処理
        return true
    }
}
