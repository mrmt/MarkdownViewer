# Markdown Viewer for macOS

macOS用のシンプルで使いやすいMarkdownビューアアプリケーションです。

## 機能

- Markdownファイルの美しいレンダリング
- ドラッグ&ドロップでファイルを開く
- テキストの選択とコピーが可能
- GitHub風のスタイリング
- キーボードショートカットによるスクロール操作

## ビルド方法

### 必要な環境

- Xcode 16.3以降

### 初回セットアップ (swift-markdownパッケージの追加)

1. Xcodeでプロジェクトを開く:

```bash
open MarkdownViewer.xcodeproj
```

1. swift-markdownパッケージを追加:

   - Xcodeのプロジェクトナビゲータで `MarkdownViewer` プロジェクトを選択
   - `PROJECT` > `MarkdownViewer` を選択
   - `Package Dependencies` タブを選択
   - `+` ボタンをクリック
   - 検索フィールドに `https://github.com/swiftlang/swift-markdown.git` を入力
   - `Add Package` をクリック
   - `Markdown` プロダクトを選択して `Add Package` をクリック

### ビルド手順

1. Xcodeで以下の手順を実行:

   - メニューから `Product` > `Build` を選択（または `⌘B`）
   - ビルドが成功したら `Product` > `Run` を選択（または `⌘R`）

### コマンドラインからのビルド

```bash
xcodebuild -project MarkdownViewer.xcodeproj -scheme MarkdownViewer -configuration Release build
```

アプリは `build/Release/MarkdownViewer.app` としてビルドされます:

## 使い方

1. アプリケーションを起動
2. 以下のいずれかの方法でファイルを開きます:
   - メニューバーから `File > Open...` を選択 (`Command-O`)
   - Markdownファイル（`.md`または`.markdown`）をウィンドウにドラッグ&ドロップ

## キーボードショートカット

MarkdownViewerは、Vim風とEmacs風の両方のキーバインドをサポートしています。

### Vim風キーバインド

| キー | 動作 |
|------|------|
| `j` | 下に1行スクロール |
| `k` | 上に1行スクロール |
| `Shift-G` | 文書の末尾にジャンプ |

### Emacs風キーバインド

| キー | 動作 |
|------|------|
| `Control-n` | 下に1行スクロール |
| `Control-p` | 上に1行スクロール |
| `Command-<` | 文書の先頭にジャンプ |
| `Command->` | 文書の末尾にジャンプ |

### その他

| キー | 動作 |
|------|------|
| `Command-O` | ファイルを開く |
| `Command-R` | ファイルを再読み込み |

## 技術スタック

- **言語**: Swift 5.0
- **フレームワーク**: SwiftUI, WebKit
- **対象OS**: macOS 13.0以降

## ライセンス

このプロジェクトはMITライセンスで公開されています。
