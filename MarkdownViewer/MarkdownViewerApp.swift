//
// MarkdownViewerApp.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // コマンドライン引数をチェック
        let args = CommandLine.arguments
        if args.count > 1 {
            let filePath = args[1]
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenMarkdownFile"),
                object: nil,
                userInfo: ["filePath": filePath]
            )
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // ファイルを開く（Finderからダブルクリックやopenコマンドで開いた場合）
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenMarkdownFile"),
            object: nil,
            userInfo: ["filePath": filename]
        )
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
