//
// MarkdownViewerApp.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI

// ファイル状態を管理するObservableObject（各ウィンドウごとのインスタンス）
class DocumentManager: ObservableObject {
    @Published var fileURL: URL?
}

@main
class MarkdownViewerApp: NSObject, NSApplicationDelegate {
    let appDelegate = AppDelegate()
    
    static func main() {
        let app = NSApplication.shared
        let delegate = MarkdownViewerApp()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        appDelegate.applicationWillFinishLaunching(notification)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        appDelegate.applicationDidFinishLaunching(notification)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        appDelegate.application(application, open: urls)
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return appDelegate.application(sender, openFile: filename)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return appDelegate.applicationShouldHandleReopen(sender, hasVisibleWindows: flag)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return appDelegate.applicationShouldTerminateAfterLastWindowClosed(sender)
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return appDelegate.applicationShouldOpenUntitledFile(sender)
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let newWindow = Notification.Name("newWindow")
    static let openFileInNewWindow = Notification.Name("openFileInNewWindow")
}

// ウィンドウコントローラークラス
class MarkdownWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingFileURLs: [URL] = []
    private var windowControllers: [MarkdownWindowController] = []
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 通知のリスナーを登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewWindow),
            name: .newWindow,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenFileInNewWindow),
            name: .openFileInNewWindow,
            object: nil
        )
    }
    
    @objc private func handleNewWindow() {
        createWindow(fileURL: nil)
    }
    
    @objc private func handleOpenFileInNewWindow(_ notification: Notification) {
        if let url = notification.object as? URL {
            createWindow(fileURL: url)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // ウィンドウがない場合は新しいウィンドウを開く
            createWindow(fileURL: nil)
        }
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // メニューバーを設定
        setupMenuBar()
        
        // アプリをアクティブにする
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // コマンドライン引数からファイルを取得
        let args = CommandLine.arguments
        if args.count > 1 {
            var skipNext = false
            for arg in args.dropFirst() {
                if skipNext {
                    skipNext = false
                    continue
                }
                if arg.hasPrefix("-") {
                    skipNext = true
                    continue
                }
                // ファイルとして存在するかチェック
                if FileManager.default.fileExists(atPath: arg) {
                    pendingFileURLs.append(URL(fileURLWithPath: arg))
                }
            }
        }
        
        // 保留中のファイルを開く
        if !pendingFileURLs.isEmpty {
            for url in pendingFileURLs {
                createWindow(fileURL: url)
            }
            pendingFileURLs.removeAll()
        } else if windowControllers.isEmpty {
            // ファイルが指定されておらず、かつウィンドウがまだ開かれていない場合のみ空のウィンドウを開く
            createWindow(fileURL: nil)
        }
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // Appメニュー
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "MarkdownViewerについて", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "MarkdownViewerを隠す", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "MarkdownViewerを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Fileメニュー
        let fileMenu = NSMenu(title: "ファイル")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        let newWindowItem = NSMenuItem(title: "新しいウィンドウ", action: #selector(newWindow), keyEquivalent: "n")
        newWindowItem.target = self
        fileMenu.addItem(newWindowItem)
        
        let openFileItem = NSMenuItem(title: "ファイルを開く...", action: #selector(openFile), keyEquivalent: "o")
        openFileItem.target = self
        fileMenu.addItem(openFileItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "ウィンドウを閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        
        // 表示メニュー
        let viewMenu = NSMenu(title: "表示")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        let reloadItem = NSMenuItem(title: "リロード", action: #selector(reloadFile), keyEquivalent: "r")
        reloadItem.target = self
        viewMenu.addItem(reloadItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc private func newWindow() {
        createWindow(fileURL: nil)
    }
    
    @objc private func openFile() {
        NotificationCenter.default.post(name: .openFile, object: nil)
    }
    
    @objc private func reloadFile() {
        NotificationCenter.default.post(name: NSNotification.Name("ReloadMarkdownFile"), object: nil)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // ファイルを開く（Finderからダブルクリックやopenコマンドで開いた場合）
        // 各ファイルごとに新しいウィンドウを作成
        for url in urls {
            createWindow(fileURL: url)
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // 旧形式のメソッド（互換性のため）
        let url = URL(fileURLWithPath: filename)
        createWindow(fileURL: url)
        return true
    }
    
    private func createWindow(fileURL: URL?) {
        // DocumentManagerを作成
        let documentManager = DocumentManager()
        if let url = fileURL {
            documentManager.fileURL = url
        }
        
        // SwiftUIビューを作成
        let contentView = ContentView(documentManager: documentManager)
            .frame(minWidth: 800, minHeight: 600)
        
        // NSWindowを作成
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.title = fileURL?.lastPathComponent ?? "MarkdownViewer"
        window.delegate = self
        
        // NSWindowControllerを作成して保持
        let windowController = MarkdownWindowController(window: window)
        windowControllers.append(windowController)
        
        windowController.showWindow(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}

// NSWindowDelegate extension
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // ウィンドウが閉じられる時、配列から削除
        if let window = notification.object as? NSWindow {
            windowControllers.removeAll { $0.window == window }
        }
    }
}
