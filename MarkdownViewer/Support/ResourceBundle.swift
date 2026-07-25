//
// ResourceBundle.swift
// MarkdownViewer
//
// Copyright (c) 2025 Jun Morimoto
// Licensed under the MIT License
//

import Foundation

/// バンドルリソース (mermaid.min.js 等) の解決
///
/// Xcodeビルド (.appバンドル) では Bundle.main、
/// SwiftPMビルド (swift run / swift test) では Bundle.module が正しい置き場所。
enum ResourceBundle {
    static var current: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}
