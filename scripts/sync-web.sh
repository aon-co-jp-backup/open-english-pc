#!/usr/bin/env bash
# 画面(web/)の正本は maid-cafe-english の web/(https://maid-cafe.tokyo と同じ画面)。ここへ同期して、PC・タブレット・スマホの
# アプリに同梱する。使い方: scripts/sync-web.sh [maid-cafe-english のパス。既定は ../open-english]
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"; src="${1:-$here/../open-english}/web"
[ -f "$src/index.html" ] || { echo "maid-cafe-english の web/ が見つかりません: $src" >&2; exit 1; }
for d in "$here/web" "$here/mobile/android/app/src/main/assets/webroot"; do
  find "$d" -mindepth 1 -maxdepth 1 ! -name README.md -exec rm -rf {} +
  (cd "$src" && tar -cf - --exclude=README.md .) | tar -xf - -C "$d"
done
echo "同期しました: $src -> web/ と Android同梱コピー"
