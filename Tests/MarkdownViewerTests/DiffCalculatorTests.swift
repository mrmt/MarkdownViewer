//
// DiffCalculatorTests.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import XCTest
@testable import MarkdownViewer

final class DiffCalculatorTests: XCTestCase {

    func testNoChanges() {
        let old = "Line 1\nLine 2"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertTrue(changes.isEmpty, "Should be empty for identical content")
    }

    func testInsertionAtEnd() {
        let old = "Line 1"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2])
    }

    func testInsertionAtStart() {
        let old = "Line 2"
        let new = "Line 1\nLine 2"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [1])
    }

    func testModification() {
        let old = "Line 1\nLine 2"
        let new = "Line 1\nLine 2 Modified"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        // Modification appears as remove old + insert new at same index
        XCTAssertEqual(changes, [2])
    }

    func testInsertionInMiddle() {
        let old = "Line 1\nLine 3"
        let new = "Line 1\nLine 2\nLine 3"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2])
    }

    func testDeletion() {
        let old = "Line 1\nLine 2"
        let new = "Line 1"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertTrue(changes.isEmpty, "Deletion should not highlight remaining lines")
    }

    func testFullReplacement() {
        let old = "Old"
        let new = "New"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [1])
    }

    func testMultipleInsertions() {
        let old = "A\nC"
        let new = "A\nB\nC\nD"
        let changes = DiffCalculator.calculateChangedLines(oldContent: old, newContent: new)
        XCTAssertEqual(changes, [2, 4])
    }
}
