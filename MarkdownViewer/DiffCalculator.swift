//
// DiffCalculator.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation

struct DiffCalculator {
    /// Calculates the line numbers (1-based) that have been changed (inserted or modified) in the new content.
    ///
    /// - Parameters:
    ///   - oldContent: The original markdown string.
    ///   - newContent: The new markdown string.
    /// - Returns: A Set of Int representing the 1-based line numbers in `newContent` that are new or modified.
    static func calculateChangedLines(oldContent: String, newContent: String) -> Set<Int> {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)

        let diff = newLines.difference(from: oldLines)

        var changedLines = Set<Int>()

        for change in diff {
            switch change {
            case .insert(let offset, _, _):
                // offset is the index in the *new* collection.
                // Convert 0-based index to 1-based line number.
                changedLines.insert(offset + 1)
            case .remove:
                // We don't track removals because they are not visible in the new content.
                break
            }
        }

        return changedLines
    }
}
