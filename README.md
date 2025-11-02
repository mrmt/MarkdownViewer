# Markdown Viewer for macOS

macOS用のシンプルで使いやすいMarkdownビューアアプリケーションです。

## 機能

- Markdownファイルの美しいレンダリング
- **複数のウィンドウで複数のファイルを同時に開ける**
- ドラッグ&ドロップでファイルを開く（複数ファイル対応）
- テキストの選択とコピーが可能
- GitHub風のスタイリング
- キーボードショートカットによるスクロール操作
- ファイルの自動監視と再読み込み

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
   - コマンドラインから: `open -a MarkdownViewer file1.md file2.md file3.md`
   - Finderからアプリにファイルをドラッグ&ドロップ

### 複数ウィンドウ機能

- **新しいウィンドウを開く**: `Command-N` で空のウィンドウを作成
- **複数ファイルを開く**: ファイル選択ダイアログで複数ファイルを選択、または複数のファイルをドラッグ&ドロップ
- **各ウィンドウは独立**: 各ウィンドウで異なるファイルを表示し、個別にファイル監視と自動再読み込みを行います

## キーボードショートカット

ファイル操作やスクロールのためのショートカットが利用できます。

### ファイル操作

| キー          | 動作                           |
|---------------|--------------------------------|
| `Command-N`   | 新しいウィンドウを開く         |
| `Command-O`   | ファイルを開く（複数選択可能） |
| `Command-R`   | ファイルを再読み込み           |

### スクロール操作

| キー                           | 動作                   |
|--------------------------------|------------------------|
| `j`, `↓`, `Control-n`    | 1行下へスクロール      |
| `k`, `↑`, `Control-p`    | 1行上へスクロール      |
| `Space`, `PageDown`      | 1ページ下へスクロール  |
| `Shift-Space`, `PageUp`  | 1ページ上へスクロール  |
| `Home`, `Command-<`      | ドキュメントの先頭へ移動 |
| `End`, `Command->`, `G`  | ドキュメントの末尾へ移動 |

## 技術スタック

- **言語**: Swift 5.0
- **フレームワーク**: SwiftUI, WebKit
- **対象OS**: macOS 13.0以降

## ライセンス

このプロジェクトはMITライセンスで公開されています。
