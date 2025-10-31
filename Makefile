# 変数定義
SCHEME = MarkdownViewer
CONFIGURATION = Release
BUILD_DIR = build
APP_NAME = MarkdownViewer.app
BUILT_APP_PATH = $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME)
INSTALL_PATH = /Applications/$(APP_NAME)

# .PHONY はファイル名と競合しないようにするためのおまじない
.PHONY: all install build clean run

# デフォルトターゲット (make とだけ打った時に実行される)
all: install

# アプリケーションのインストール
install: build
	@echo "📂 アプリケーションを $(INSTALL_PATH) にインストールします..."
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "   古いバージョンを削除しています..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@cp -R "$(BUILT_APP_PATH)" "/Applications/"
	@echo "🎉 $(APP_NAME) のインストールが完了しました！"
	@echo "   Finderで /Applications フォルダを確認してください。"

# xcodebuild を使ったアプリケーションのビルド
build:
	@echo "🚀 $(SCHEME) のリリースビルドを開始します..."
	@xcodebuild build \
	  -project $(SCHEME).xcodeproj \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -derivedDataPath "$(BUILD_DIR)"
	@echo "✅ ビルドが完了しました。"

# ビルド成果物のクリーンアップ
clean:
	@echo "🧹 ビルド成果物を削除します..."
	@rm -rf "$(BUILD_DIR)"
	@echo "✅ 削除しました。"

# アプリケーションの実行 (デバッグ用)
run: build
	@echo "🏃 $(APP_NAME) を実行します..."
	@open "$(BUILT_APP_PATH)"
