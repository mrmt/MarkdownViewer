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
    @Binding var webView: WKWebView?
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
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
            
            // メインスレッドでHTMLをロード
            DispatchQueue.main.async {
                let (html, baseURL) = self.renderMarkdownToHTML(self.markdown)
                nsView.loadHTMLString(html, baseURL: baseURL)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var savedScrollPosition: CGPoint?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
    
    private func renderMarkdownToHTML(_ markdown: String) -> (String, URL?) {
        let document = Document(parsing: markdown)
        var formatter = HTMLFormatter()
        formatter.visit(document)
        let htmlContent = formatter.result
        let hasMermaid = formatter.hasMermaid
        
        // baseURLを設定（リソースを読み込むため）
        var baseURL: URL? = nil
        if let resourcePath = Bundle.main.resourcePath {
            baseURL = URL(fileURLWithPath: resourcePath)
        }
        
        // mermaid.jsをバンドルから読み込む
        var mermaidScript = ""
        if hasMermaid {
            // baseURLを使用してスクリプトタグで読み込む
            mermaidScript = "<script src=\"mermaid.min.js\"></script>"
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            \(mermaidScript)
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    padding: 40px;
                    max-width: 900px;
                    margin: 0 auto;
                    color: #333;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
                h3 { font-size: 1.25em; }
                code {
                    background-color: rgba(175, 184, 193, 0.2);
                    padding: 0.2em 0.4em;
                    border-radius: 3px;
                    font-family: 'SF Mono', Monaco, 'Courier New', monospace;
                    font-size: 0.85em;
                }
                pre {
                    background-color: #f6f8fa;
                    padding: 16px;
                    border-radius: 6px;
                    overflow: auto;
                }
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                a {
                    color: #0366d6;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                ul, ol {
                    padding-left: 2em;
                    margin: 0.5em 0;
                }
                li {
                    margin: 0.25em 0;
                }
                ul ul, ol ul, ul ol, ol ol {
                    margin: 0.25em 0;
                }
                p {
                    margin: 1em 0;
                }
                strong {
                    font-weight: 600;
                }
                blockquote {
                    border-left: 4px solid #dfe2e5;
                    padding-left: 1em;
                    margin-left: 0;
                    color: #6a737d;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                }
                th, td {
                    border: 1px solid #dfe2e5;
                    padding: 6px 13px;
                }
                th {
                    background-color: #f6f8fa;
                    font-weight: 600;
                }
                hr {
                    border: 0;
                    border-top: 1px solid #dfe2e5;
                    margin: 24px 0;
                }
                .mermaid {
                    text-align: center;
                    margin: 1em 0;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
            \(hasMermaid ? """
            <script>
                if (typeof mermaid !== 'undefined') {
                    mermaid.initialize({ startOnLoad: true, theme: 'default' });
                } else {
                    console.error('mermaid.jsが読み込まれませんでした');
                }
            </script>
            """ : "")
        </body>
        </html>
        """
        
        return (html, baseURL)
    }
}

// HTMLフォーマッタ
struct HTMLFormatter: MarkupWalker {
    var result = ""
    var isInListItem = false
    var hasMermaid = false
    
    static func format(_ markup: Markup) -> String {
        var formatter = HTMLFormatter()
        formatter.visit(markup)
        return formatter.result
    }
    
    mutating func visitDocument(_ document: Markdown.Document) {
        descendInto(document)
    }
    
    mutating func visitHeading(_ heading: Markdown.Heading) {
        let level = heading.level
        result += "<h\(level)>"
        descendInto(heading)
        result += "</h\(level)>"
    }
    
    mutating func visitParagraph(_ paragraph: Markdown.Paragraph) {
        if !isInListItem {
            result += "<p>"
        }
        descendInto(paragraph)
        if !isInListItem {
            result += "</p>"
        }
    }
    
    mutating func visitText(_ text: Markdown.Text) {
        result += text.string.htmlEscaped
    }
    
    mutating func visitEmphasis(_ emphasis: Markdown.Emphasis) {
        result += "<em>"
        descendInto(emphasis)
        result += "</em>"
    }
    
    mutating func visitStrong(_ strong: Markdown.Strong) {
        result += "<strong>"
        descendInto(strong)
        result += "</strong>"
    }
    
    mutating func visitInlineCode(_ inlineCode: Markdown.InlineCode) {
        result += "<code>\(inlineCode.code.htmlEscaped)</code>"
    }
    
    mutating func visitCodeBlock(_ codeBlock: Markdown.CodeBlock) {
        let language = codeBlock.language ?? ""
        if language.lowercased() == "mermaid" {
            hasMermaid = true
            result += "<div class=\"mermaid\">"
            result += codeBlock.code.htmlEscaped
            result += "</div>"
        } else {
            result += "<pre><code"
            if !language.isEmpty {
                result += " class=\"language-\(language.htmlEscaped)\""
            }
            result += ">"
            result += codeBlock.code.htmlEscaped
            result += "</code></pre>"
        }
    }
    
    mutating func visitLink(_ link: Markdown.Link) {
        result += "<a href=\"\(link.destination ?? "")\">"
        descendInto(link)
        result += "</a>"
    }
    
    mutating func visitUnorderedList(_ unorderedList: Markdown.UnorderedList) {
        result += "<ul>"
        descendInto(unorderedList)
        result += "</ul>"
    }
    
    mutating func visitOrderedList(_ orderedList: Markdown.OrderedList) {
        result += "<ol>"
        descendInto(orderedList)
        result += "</ol>"
    }
    
    mutating func visitListItem(_ listItem: Markdown.ListItem) {
        result += "<li>"
        let wasInListItem = isInListItem
        isInListItem = true
        descendInto(listItem)
        isInListItem = wasInListItem
        result += "</li>"
    }
    
    mutating func visitBlockQuote(_ blockQuote: Markdown.BlockQuote) {
        result += "<blockquote>"
        descendInto(blockQuote)
        result += "</blockquote>"
    }
    
    mutating func visitThematicBreak(_ thematicBreak: Markdown.ThematicBreak) {
        result += "<hr>"
    }
    
    mutating func visitLineBreak(_ lineBreak: Markdown.LineBreak) {
        result += "<br>"
    }
    
    mutating func visitSoftBreak(_ softBreak: Markdown.SoftBreak) {
        result += " "
    }
    
    mutating func visitTable(_ table: Markdown.Table) {
        result += "<table>"
        descendInto(table)
        result += "</table>"
    }
    
    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) {
        result += "<thead><tr>"
        descendInto(tableHead)
        result += "</tr></thead>"
    }
    
    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) {
        result += "<tbody>"
        descendInto(tableBody)
        result += "</tbody>"
    }
    
    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) {
        result += "<tr>"
        descendInto(tableRow)
        result += "</tr>"
    }
    
    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) {
        let tag = tableCell.colspan > 1 ? "th" : "td"
        result += "<\(tag)>"
        descendInto(tableCell)
        result += "</\(tag)>"
    }
    
    private mutating func descendInto(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }
}

extension String {
    var htmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
