#!/bin/bash
#
# Package.swift と project.yml の依存バージョン宣言が一致しているか照合する
#
# 依存は SwiftPM 用 (Package.swift) と XcodeGen 用 (project.yml) の2箇所で宣言する。
# dependabot は Package.swift しか更新しないため、放置すると project.yml が
# 取り残され、SwiftPM ビルドと Xcode (配布物) ビルドで別バージョンが使われる。
# pbxproj は project.yml から生成されるので、既存の xcodegen 整合性チェックでは
# この食い違いを検出できない。
#
# 使い方: ./scripts/check-dependency-versions.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

# Package.swift から "URL バージョン" を抽出
# 例: .package(url: "https://.../swift-markdown.git", .upToNextMinor(from: "0.8.0"))
spm_versions=$(grep -oE '\.package\(url: *"[^"]+"[^)]*from: *"[^"]+"' Package.swift \
    | sed -E 's|.*url: *"([^"]+)".*from: *"([^"]+)".*|\1 \2|' \
    | sort)

# project.yml の packages: 配下から "URL バージョン" を抽出
project_versions=$(awk '
    /^packages:/ { in_packages = 1; next }
    in_packages && /^[^ ]/ { in_packages = 0 }
    # 新しいパッケージ名の行に来たら、直前のパッケージを出力
    in_packages && /^  [^ ]+:[[:space:]]*$/ {
        if (url != "") print url, version
        url = ""; version = ""
        next
    }
    in_packages && $1 == "url:" { url = $2 }
    in_packages && $1 ~ /Version:$/ { version = $2 }
    END { if (url != "") print url, version }
' project.yml | sort)

# 抽出できない場合は書式変更の可能性があるため、黙って通さず失敗させる
if [ -z "$spm_versions" ]; then
    echo "エラー: Package.swift から依存バージョンを抽出できません。書式が変わった可能性があります。" >&2
    exit 1
fi
if [ -z "$project_versions" ]; then
    echo "エラー: project.yml から依存バージョンを抽出できません。書式が変わった可能性があります。" >&2
    exit 1
fi

if [ "$spm_versions" != "$project_versions" ]; then
    echo "エラー: Package.swift と project.yml の依存バージョンが一致しません。" >&2
    echo >&2
    echo "  Package.swift:" >&2
    echo "$spm_versions" | sed 's/^/    /' >&2
    echo "  project.yml:" >&2
    echo "$project_versions" | sed 's/^/    /' >&2
    echo >&2
    echo "両方を同じバージョンに揃えたうえで 'xcodegen generate' を実行してください。" >&2
    exit 1
fi

echo "依存バージョンは一致しています:"
echo "$spm_versions" | sed 's/^/  /'
