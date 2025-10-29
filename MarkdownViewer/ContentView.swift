//
// ContentView.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var documentManager: DocumentManager
    @State private var markdownContent: String = ""
    @State private var filePath: String = ""
    @State private var isDragOver = false
    
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
        } catch {
            print("ファイルの読み込みに失敗: \(error)")
        }
    }
    
    private func reloadMarkdownFile() {
        guard !filePath.isEmpty else { return }
        loadMarkdownFile(path: filePath)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(documentManager: DocumentManager.shared)
    }
}
