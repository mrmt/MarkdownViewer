//
// MarkdownWebView.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import SwiftUI
import WebKit
import Markdown

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let changedLines: Set<Int>
    let fileDirectoryURL: URL?
    /// 読み込み完了時にスクロール先としたい見出しのフラグメント (例: "inner" → #inner)
    /// one-shot: コンポーネントが消費したら親側で nil にクリアされる
    @Binding var initialFragment: String?
    @Binding var webView: WKWebView?

    init(markdown: String, changedLines: Set<Int> = [], fileDirectoryURL: URL? = nil, initialFragment: Binding<String?> = .constant(nil), webView: Binding<WKWebView?>) {
        self.markdown = markdown
        self.changedLines = changedLines
        self.fileDirectoryURL = fileDirectoryURL
        self._initialFragment = initialFragment
        self._webView = webView
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // リンククリックをJS経由でSwiftに通知するためのメッセージハンドラを登録
        configuration.userContentController.add(context.coordinator, name: "linkClicked")

        let webView = FocusableWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // テキスト選択とコピーを有効にする
        webView.allowsMagnification = true

        // WKWebViewの参照を保存
        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 現在のスクロール位置を保存してからHTMLをロード
        nsView.evaluateJavaScript("window.pageYOffset") { result, error in
            if let yOffset = result as? CGFloat {
                context.coordinator.savedScrollPosition = CGPoint(x: 0, y: yOffset)
            }
            // fragment (#id) 指定がある場合はスクロール位置復元より優先する。
            // 一度消費したら親側 state をクリアして、以降の自動リロード等で
            // 再度スクロールされないようにする (one-shot)
            if let fragment = self.initialFragment {
                context.coordinator.pendingFragment = fragment
                DispatchQueue.main.async {
                    self.initialFragment = nil
                }
            } else {
                context.coordinator.pendingFragment = nil
            }
            // メインスレッドでHTMLをロード
            DispatchQueue.main.async {
                let (html, baseURL) = self.renderMarkdownToHTML(self.markdown, changedLines: self.changedLines)
                nsView.loadHTMLString(html, baseURL: baseURL)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var savedScrollPosition: CGPoint?
        /// 次のロード完了時にスクロール先としたい要素のid (fragment)。一度適用したらnilに戻す
        var pendingFragment: String?

        // JSから送られたリンククリックを処理
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "linkClicked",
                  let href = message.body as? String,
                  let url = URL(string: href) else {
                return
            }
            handleLinkClick(url: url)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // リンククリックは基本的にJSインターセプタ側でpreventDefaultされるため、
            // ここには届かない。保険として実装するフォールバック:
            //   - ページ内アンカー (同一ドキュメント内fragment) → WebKitの既定動作を許可
            //   - それ以外の linkActivated → cancel してSwift側で処理
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if isSameDocumentFragmentNavigation(target: url, current: webView.url) {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            handleLinkClick(url: url)
        }

        /// 現在表示中のドキュメントと scheme/host/path が同じで fragment のみ異なる navigation かどうか
        private func isSameDocumentFragmentNavigation(target: URL, current: URL?) -> Bool {
            guard target.fragment != nil, let current = current else { return false }
            return target.scheme == current.scheme
                && target.host == current.host
                && target.path == current.path
        }

        private func handleLinkClick(url: URL) {
            let scheme = url.scheme?.lowercased()
            switch scheme {
            case "http", "https":
                NSWorkspace.shared.open(url)
            case "file":
                openLocalMarkdownFile(url: url)
            default:
                // その他スキーム（mailto 等）はシステムに委ねる
                NSWorkspace.shared.open(url)
            }
        }

        private func openLocalMarkdownFile(url: URL) {
            // URL.pathExtension/path は fragment/query を含まないので、拡張子・存在判定は url そのもので安全に行える
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown",
                  FileManager.default.isReadableFile(atPath: url.path) else {
                // readできない or markdownでない → 何もしない
                return
            }

            // query は現状使わないので除去。fragment は受信側で見出しスクロールに利用するため保持する
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            let forwardURL = components?.url ?? url

            NotificationCenter.default.post(name: .openFileInNewWindow, object: forwardURL)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // fragment (ページ内アンカー) が指定されている場合はそこにスクロールする (位置復元より優先)
            if let fragment = pendingFragment, !fragment.isEmpty {
                pendingFragment = nil
                savedScrollPosition = nil
                // JSコンテキストへ埋め込むため文字列エスケープ
                let escaped = fragment
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                let script = "document.getElementById('\(escaped)')?.scrollIntoView()"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    webView.evaluateJavaScript(script, completionHandler: nil)
                }
                return
            }

            // Navigation completed successfully - スクロール位置を復元
            if let position = savedScrollPosition {
                // DOMの描画完了を待つため、少し遅延させて復元
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.restoreScrollPosition(webView, position: position)
                }
                savedScrollPosition = nil
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Navigation failed
            savedScrollPosition = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Provisional navigation failed
            savedScrollPosition = nil
        }

        private func restoreScrollPosition(_ webView: WKWebView, position: CGPoint) {
            let script = "window.scrollTo(\(position.x), \(position.y));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    // WKWebViewのサブクラスを作成して、マウスクリック時にフォーカスを設定
    class FocusableWebView: WKWebView {
        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            // マウスクリック時にフォーカスを設定して、編集メニューが動作するようにする
            window?.makeFirstResponder(self)
        }
    }
    
    
    // スクロール操作用のメソッド

    /// WebViewでJavaScriptスクロールコマンドを実行する共通ヘルパー
    private static func executeScroll(_ webView: WKWebView?, script: String) {
        guard let webView = webView else { return }
        webView.evaluateJavaScript(script)
    }

    static func scrollDown(_ webView: WKWebView?, lineHeight: CGFloat = 20) {
        executeScroll(webView, script: "window.scrollBy(0, \(lineHeight));")
    }

    static func scrollUp(_ webView: WKWebView?, lineHeight: CGFloat = 20) {
        executeScroll(webView, script: "window.scrollBy(0, -\(lineHeight));")
    }

    static func scrollPageDown(_ webView: WKWebView?) {
        executeScroll(webView, script: "window.scrollBy(0, window.innerHeight);")
    }

    static func scrollPageUp(_ webView: WKWebView?) {
        executeScroll(webView, script: "window.scrollBy(0, -window.innerHeight);")
    }

    static func scrollToTop(_ webView: WKWebView?) {
        executeScroll(webView, script: "window.scrollTo(0, 0);")
    }

    static func scrollToBottom(_ webView: WKWebView?) {
        executeScroll(webView, script: "window.scrollTo(0, document.body.scrollHeight);")
    }

    private func renderMarkdownToHTML(_ markdown: String, changedLines: Set<Int>) -> (String, URL?) {
        let (frontmatter, markdownBody) = FrontmatterRenderer.split(markdown)

        // Markdownをパースしてhtml生成
        let document = Document(parsing: markdownBody)
        var formatter = HTMLFormatter(changedLines: changedLines, baseFileURL: fileDirectoryURL)
        formatter.visit(document)
        let htmlContent = formatter.result
        let hasMermaid = formatter.hasMermaid
        let frontmatterHTML = frontmatter.map(FrontmatterRenderer.html(for:)) ?? ""
        let contentSections = [frontmatterHTML, htmlContent].filter { !$0.isEmpty }

        // baseURLを設定（リソースを読み込むため）
        let baseURL: URL? = {
            guard let resourcePath = Bundle.main.resourcePath else { return nil }
            return URL(fileURLWithPath: resourcePath)
        }()

        // 完全なHTMLドキュメントを構築
        let html = MarkdownStylesheet.buildHTMLDocument(content: contentSections.joined(separator: "\n"), mermaidEnabled: hasMermaid)

        return (html, baseURL)
    }
}
