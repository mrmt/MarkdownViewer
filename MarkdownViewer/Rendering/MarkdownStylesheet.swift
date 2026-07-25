//
// MarkdownStylesheet.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//
// HTMLドキュメントの組み立て (CSS / スクリプト / テンプレート)
// 注: CSSを外部リソース化しないのは、Bundle解決がSwiftPM/Xcodeビルドで
// 二重化してバグ源になるため。文字列定数のまま分離する。
//

import Foundation

enum MarkdownStylesheet {

    /// CSSスタイルシート（GitHub風のマークダウンスタイル）
    static let cssStyleSheet = """
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
        .frontmatter {
            background-color: #f7f0ff;
            border: 1px solid #eadcff;
            border-radius: 6px;
            color: #5f4b8b;
            font-family: 'SF Mono', Monaco, 'Courier New', monospace;
            font-size: 0.9em;
            margin: 0 0 24px 0;
            padding: 16px;
            white-space: pre-wrap;
        }
        .changed {
            background-color: #fff5b1;
            border-radius: 3px;
        }
        """

    /// リンククリックをSwift側に通知するスクリプト
    /// - fragment のみは JS 側で scrollIntoView してページ内ジャンプ
    /// - それ以外は Swift 側 (WKScriptMessageHandler) にURLを通知
    static let linkInterceptorScript = """
        <script>
            document.addEventListener('click', function(e) {
                const a = e.target.closest('a');
                if (!a) return;
                const href = a.getAttribute('href');
                if (!href) return;
                e.preventDefault();
                if (href.startsWith('#')) {
                    const target = document.getElementById(href.slice(1));
                    if (target) target.scrollIntoView({behavior: 'smooth'});
                    return;
                }
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkClicked) {
                    window.webkit.messageHandlers.linkClicked.postMessage(a.href || href);
                }
            }, true);
        </script>
        """

    /// Mermaid.jsのスクリプトタグを生成
    static func mermaidScriptTag(enabled: Bool) -> String {
        enabled ? "<script src=\"mermaid.min.js\"></script>" : ""
    }

    /// Mermaid.jsの初期化スクリプトを生成
    static func mermaidInitializationScript(enabled: Bool) -> String {
        guard enabled else { return "" }
        return """
            <script>
                if (typeof mermaid !== 'undefined') {
                    mermaid.initialize({ startOnLoad: true, theme: 'default' });
                } else {
                    console.error('mermaid.jsが読み込まれませんでした');
                }
            </script>
            """
    }

    /// 完全なHTMLドキュメントを構築
    static func buildHTMLDocument(content: String, mermaidEnabled: Bool) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            \(mermaidScriptTag(enabled: mermaidEnabled))
            <style>
                \(cssStyleSheet)
            </style>
        </head>
        <body>
            \(content)
            \(mermaidInitializationScript(enabled: mermaidEnabled))
            \(linkInterceptorScript)
        </body>
        </html>
        """
    }
}
