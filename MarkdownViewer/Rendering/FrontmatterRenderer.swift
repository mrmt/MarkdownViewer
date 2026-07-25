//
// FrontmatterRenderer.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation

enum FrontmatterRenderer {
    static func split(_ markdown: String) -> (frontmatter: String?, body: String) {
        guard let firstLineRange = nextLineRange(in: markdown, startingAt: markdown.startIndex),
              String(markdown[firstLineRange]).trimmingCharacters(in: .newlines) == "---" else {
            return (nil, markdown)
        }

        var scanIndex = firstLineRange.upperBound

        while let lineRange = nextLineRange(in: markdown, startingAt: scanIndex) {
            let line = String(markdown[lineRange]).trimmingCharacters(in: .newlines)
            if line == "---" || line == "..." {
                let frontmatter = String(markdown[..<lineRange.upperBound])
                let body = lineRange.upperBound < markdown.endIndex ? String(markdown[lineRange.upperBound...]) : ""
                return (frontmatter, body)
            }
            scanIndex = lineRange.upperBound
        }

        return (nil, markdown)
    }

    static func html(for frontmatter: String) -> String {
        "<pre class=\"frontmatter\">\(frontmatter.htmlEscaped)</pre>"
    }

    private static func nextLineRange(in string: String, startingAt index: String.Index) -> Range<String.Index>? {
        guard index < string.endIndex else { return nil }

        if let newlineIndex = string[index...].firstIndex(of: "\n") {
            return index..<string.index(after: newlineIndex)
        }

        return index..<string.endIndex
    }
}
