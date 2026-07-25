//
// HTMLFormatter.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation
import Markdown

// HTMLフォーマッタ
struct HTMLFormatter: MarkupWalker {
    var result = ""
    var isInListItem = false
    var hasMermaid = false
    var changedLines: Set<Int>
    var baseFileURL: URL?
    /// 見出しID重複カウンタ (同名見出しには -1, -2 を付与)
    var usedHeadingIds: [String: Int] = [:]

    init(changedLines: Set<Int> = [], baseFileURL: URL? = nil) {
        self.changedLines = changedLines
        self.baseFileURL = baseFileURL
    }

    // MARK: - Link Resolution

    /// マークダウン内のリンク先を解決し、相対パスをmarkdownファイル基準の絶対URLに変換する
    private func resolveLinkDestination(_ destination: String) -> String {
        guard !destination.isEmpty else { return "" }

        // fragment のみ (#section など) はそのまま
        if destination.hasPrefix("#") {
            return destination
        }

        // 絶対URL (scheme付き) はそのまま
        if let url = URL(string: destination), url.scheme != nil {
            return destination
        }

        // 相対パス → markdownファイルのディレクトリ基準で絶対化
        // URL(string:relativeTo:) は fragment や query を正しく保持する
        guard let baseURL = baseFileURL,
              let resolved = URL(string: destination, relativeTo: baseURL)?.absoluteURL.standardized else {
            return destination
        }
        return resolved.absoluteString
    }

    // MARK: - Change Detection Helpers

    private func isChanged(_ markup: Markup) -> Bool {
        guard let range = markup.range else { return false }
        let lines = range.lowerBound.line...range.upperBound.line
        return !changedLines.isDisjoint(with: lines)
    }

    private func isFullyChanged(_ markup: Markup) -> Bool {
        guard let range = markup.range else { return false }
        let lines = range.lowerBound.line...range.upperBound.line
        return lines.allSatisfy { changedLines.contains($0) }
    }

    private func styleClass(_ markup: Markup, baseClass: String = "", fullCheck: Bool = false) -> String {
        let changed = fullCheck ? isFullyChanged(markup) : isChanged(markup)
        var classes = [String]()
        if !baseClass.isEmpty { classes.append(baseClass) }
        if changed { classes.append("changed") }

        return classes.isEmpty ? "" : " class=\"\(classes.joined(separator: " "))\""
    }

    // MARK: - Heading ID (slug)

    /// Markup から平文テキストを再帰的に抽出
    static func extractPlainText(_ markup: Markup) -> String {
        if let text = markup as? Markdown.Text {
            return text.string
        }
        if let code = markup as? Markdown.InlineCode {
            return code.code
        }
        var result = ""
        for child in markup.children {
            result += extractPlainText(child)
        }
        return result
    }

    /// GitHub 風の簡易 slug 化: 小文字化、英数以外を - に変換、連続-を1つに、両端の-を除去
    static func slugify(_ text: String) -> String {
        var slug = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if scalar == " " || scalar == "-" || scalar == "_" {
                slug.append("-")
            }
            // その他の記号は捨てる
        }
        // 連続する - を 1 つに
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        while slug.hasPrefix("-") { slug.removeFirst() }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug
    }

    private mutating func uniqueHeadingId(for text: String) -> String {
        let base = Self.slugify(text)
        guard !base.isEmpty else { return "" }
        if let count = usedHeadingIds[base] {
            usedHeadingIds[base] = count + 1
            return "\(base)-\(count)"
        } else {
            usedHeadingIds[base] = 1
            return base
        }
    }

    mutating func visitDocument(_ document: Markdown.Document) {
        descendInto(document)
    }

    mutating func visitHeading(_ heading: Markdown.Heading) {
        let level = heading.level
        let id = uniqueHeadingId(for: Self.extractPlainText(heading))
        let idAttr = id.isEmpty ? "" : " id=\"\(id.htmlEscaped)\""
        result += "<h\(level)\(idAttr)\(styleClass(heading))>"
        descendInto(heading)
        result += "</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Markdown.Paragraph) {
        if !isInListItem {
            result += "<p\(styleClass(paragraph))>"
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
            // Apply highlighting to the <pre> tag for code blocks
            result += "<pre\(styleClass(codeBlock))><code"
            if !language.isEmpty {
                result += " class=\"language-\(language.htmlEscaped)\""
            }
            result += ">"
            result += codeBlock.code.htmlEscaped
            result += "</code></pre>"
        }
    }

    mutating func visitLink(_ link: Markdown.Link) {
        let href = resolveLinkDestination(link.destination ?? "")
        result += "<a href=\"\(href.htmlEscaped)\">"
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
        // Use fullCheck (isFullyChanged) for ListItems to avoid highlighting whole complex items
        result += "<li\(styleClass(listItem, fullCheck: true))>"
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
        result += "<hr\(styleClass(thematicBreak))>"
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
        result += "<tr\(styleClass(tableRow))>"
        descendInto(tableRow)
        result += "</tr>"
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) {
        // ヘッダ行 (Table.Head 配下) のセルだけ <th>。colspan は属性として出力する
        let isHeaderCell = sequence(first: tableCell.parent, next: { $0?.parent })
            .contains { $0 is Markdown.Table.Head }
        let tag = isHeaderCell ? "th" : "td"
        let colspanAttr = tableCell.colspan > 1 ? " colspan=\"\(tableCell.colspan)\"" : ""
        result += "<\(tag)\(colspanAttr)>"
        descendInto(tableCell)
        result += "</\(tag)>"
    }

    private mutating func descendInto(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }
}
