# 開発方針＆開発環境ルール（open-english-pc）

開発方針・開発環境ルールの**正本**は
[`open-raid-z`](https://github.com/aon-co-jp/open-raid-z) の `CLAUDE.md`
（確認不要の自動継続／リミット解除後の自動再開・白画面バグ等を見逃さない
検証徹底・参照資料一覧など、全リポジトリ共通ルールはそちらを参照）。

## このリポジトリの役割

[`open-english`](https://github.com/aon-co-jp/open-english) の**クライアント**
（デスクトップ／タブレット／モバイル）を、本体（共有デモ環境＋配信サーバー
`open-english-server`）から分離して集約するモノレポ。

- `pc/` … Windows / Linux / macOS デスクトップ版
- `tablet/` … タブレット版
- `mobile/` … モバイル版

## 移設状況（HANDOFF）

- **2026-09-10 リポジトリ新設**: `aon-co-jp/open-english-pc` を作成（public、
  デフォルトブランチ `main`）。モノレポ骨組み（`pc/` `tablet/` `mobile/` +
  各 README）を配置。
- **2026-09-10 Phase 2 完了**: `git filter-repo` で `open-english` から
  クライアント資産を**履歴保持**で移設し、`--allow-unrelated-histories` で
  骨組みへマージ（203 コミット）。
  - `web/` … 共有 Web クライアント（`index.html` `style.css` `app.js`
    `auto-update.js` `version.json` `manifest.json` `exam-prep-questions.json`
    `sw.js` `facebook.html` `qr-confirm.html` `vault.html` `icons/`）
  - `mobile/android/` … 本体 `android/`
- **Phase 2b（未）**: `open-english` 本体は現在も同じファイルのコピーを保持して
  デモ配信中。本体の `.github/workflows/release.yml`（Package/cp）・
  `installer/windows/open-english.iss`（Source パス）・`server/src/main.rs`
  （静的 root 解決）・`android/` 参照を、この `web/` を参照する形へ切り替え、
  取得方法（submodule / CI clone）を決めてから本体のコピーを削除する。
- **Phase 3（未）**: 「起動してメンテナンス表示中は 30 秒間隔」で
  `self_update` ＋ `component_update`（**関連リポジトリ全て**のバージョン
  チェックと自動アップグレード）を回す拡張。正本ロジックは
  `open-english/server/src/self_update.rs` ／ `component_update.rs`。
  通常時の定期チェックは 30 分（`open-english` 側で 2026-09-09 に 6h→30m 済み）。
- **2026-09-14 Androidキーボード自動スクロールの実機根本修正(v0.8.7)**:
  ユーザー報告「縦スマホでキーボード表示より上に自動スクロールしない」を
  OPPO Reno11A実機（ADB接続）で繰り返し検証し、3件の実バグを特定・修正した。
  1. **根本原因**: `WindowInsetsCompat.Type.ime()` + `View.setPadding()`
     でWebViewへキーボード高さ分のbottom paddingを適用する方式は、padding
     自体は正しく適用されていたが、Chromium系WebViewが`onSizeChanged`を
     受け取らずJS側`window.innerHeight`/`visualViewport`が一切更新されない
     ことを実機ログ(`currentPadding=897`と適用は確認できるのに画面上は
     無反応)で特定した。`WebView.layoutParams.height`を直接書き換える方式
     (`getWindowVisibleDisplayFrame`でキーボード高さを算出)に切り替え、
     実際のビュー寸法変更として確実に`onSizeChanged`を発火させることで
     解決。ADB実機テストで入力欄がキーボード上に正しく自動スクロールされ、
     文字入力も可能なことを確認済み。
  2. ネイティブ`CLOSE`/`OPEN SETUP`ボタンが画面右上で重なって表示される
     バグ(`closeSetupBtn`がローカル変数でサーバー起動成功時の自動非表示
     処理から参照できず、非表示にし忘れていた)を修正。tablet flavor側の
     レイアウトにも同じオーバーレイボタンを追加。
  3. `assets/webroot/`(APK同梱の静的アセット)が`web/`(正本)から手動`cp`
     でしか同期されておらず、同期忘れで旧コンテンツが実機に配信され
     続ける実害を繰り返し引き起こしていた問題を、Gradle `preBuild`依存の
     自動コピータスク(`app/build.gradle.kts`の`syncWebrootFromWeb`)で解消。
  詳細は`mobile/android/app/src/main/java/tokyo/runo/openenglish/MainActivity.kt`
  のコメント参照。

## GitHub organization

https://github.com/aon-co-jp

## API 方針: REST 全廃・gRPC / Connect へ (2026-11-04)

### 日本語
- **REST は全廃する。新しい API は REST で作らない。** ブラウザや `curl` から呼ぶ API は **Connect の単純呼び出し**(`POST /<パッケージ>.<Service>/<Method>`、`content-type: application/json`、本文は JSON)、サービス間は **gRPC / gRPC-web**(RPoem の管理API `open_runo.admin.v1.Admin` と同じ流儀)。ストリーミングは、必要になってから。
- **既存の REST は、触るときに順に移す。** 移したら旧 REST の経路は消す。移行が終わるまで残るが、**新規には追加しない**。
- **JSON は RS-JSON に統一**する(読み込みは `from_str_secure` / `parse_secure` でサイズ・深さ・重複キーの上限つき、書き出しは `rust_json::fast`)。ブラウザの WASM に `prost` は入れない(サイズが増えるため)。
- **例外(自分たちの API ではなく、相手の規格が決めているもの)**: ACME、OAuth/OIDC のコールバック、第三者(GitHub など)からの Webhook、ヘルスチェック、静的ファイル配信、OTLP など。これらは規格どおりの HTTP を受ける。
- 参考実装: `RPoem`(`open_runo.admin.v1.Admin`)、`open-easy-web`(`server/src/connect.rs`、`proto/open_easy_web/admin/v1/admin.proto`)。
- ※ このリポジトリのコードが既に方針どおりかどうかは、各リポジトリの現状による。この節は方針の記録であり、コードの変更を意味しない。

### English
- **REST is being abolished. New APIs are not built as REST.** APIs called from browsers or `curl` use **Connect unary calls** (`POST /<package>.<Service>/<Method>`, `content-type: application/json`, JSON body); service-to-service calls use **gRPC / gRPC-web** (the same style as RPoem's admin API `open_runo.admin.v1.Admin`). Streaming only when it is actually needed.
- **Existing REST endpoints are migrated one by one, when they are touched.** The old REST route is removed once migrated. Until migration is finished they remain, but **no new ones are added**.
- **JSON is unified on RS-JSON**: reading with `from_str_secure` / `parse_secure` (size, depth and duplicate-key limits), writing with `rust_json::fast`. `prost` is not put into browser WASM (it would grow the binary).
- **Exceptions (shapes dictated by someone else's standard, not our own API)**: ACME, OAuth/OIDC callbacks, webhooks from third parties (e.g. GitHub), health checks, static file serving, OTLP, and so on. These accept plain HTTP as the standard requires.
- Reference implementations: `RPoem` (`open_runo.admin.v1.Admin`) and `open-easy-web` (`server/src/connect.rs`, `proto/open_easy_web/admin/v1/admin.proto`).
- Note: whether the code in a given repository already follows this policy depends on that repository. This section records the policy; it does not mean the code has been changed.

### Deutsch (KI-Übersetzung, noch nicht von Muttersprachlern geprüft)
- **REST wird abgeschafft. Neue APIs werden nicht als REST gebaut.** APIs, die aus dem Browser oder mit `curl` aufgerufen werden, nutzen **Connect-Unary-Aufrufe** (`POST /<Paket>.<Service>/<Methode>`, `content-type: application/json`, JSON-Body); zwischen Diensten gilt **gRPC / gRPC-web** (wie bei der Admin-API von RPoem, `open_runo.admin.v1.Admin`). Streaming erst, wenn es wirklich nötig ist.
- **Bestehende REST-Endpunkte werden einzeln migriert, sobald man sie anfasst.** Nach der Migration wird die alte REST-Route entfernt. Bis dahin bleiben sie bestehen, es werden aber **keine neuen hinzugefügt**.
- **JSON wird auf RS-JSON vereinheitlicht**: Lesen mit `from_str_secure` / `parse_secure` (Grenzen für Größe, Tiefe und doppelte Schlüssel), Schreiben mit `rust_json::fast`. `prost` kommt nicht in Browser-WASM (die Datei würde größer).
- **Ausnahmen (Formate, die ein fremder Standard vorgibt, nicht unsere eigene API)**: ACME, OAuth/OIDC-Callbacks, Webhooks von Dritten (z. B. GitHub), Health-Checks, statische Dateien, OTLP usw. Diese nehmen schlichtes HTTP entgegen, wie es der Standard verlangt.
- Referenzimplementierungen: `RPoem` (`open_runo.admin.v1.Admin`) und `open-easy-web` (`server/src/connect.rs`, `proto/open_easy_web/admin/v1/admin.proto`).
- Hinweis: Ob der Code eines Repositorys diese Richtlinie schon befolgt, hängt vom jeweiligen Repository ab. Dieser Abschnitt hält die Richtlinie fest; er bedeutet nicht, dass der Code bereits geändert wurde.

### Русский (машинный перевод, носителями языка ещё не проверен)
- **REST полностью отменяется. Новые API не создаются как REST.** API, вызываемые из браузера или через `curl`, используют **унарные вызовы Connect** (`POST /<пакет>.<Service>/<Method>`, `content-type: application/json`, тело — JSON); между сервисами — **gRPC / gRPC-web** (так же, как административный API RPoem, `open_runo.admin.v1.Admin`). Потоковая передача — только когда она действительно нужна.
- **Существующие REST-эндпоинты переносятся по одному, когда до них доходят руки.** После переноса старый REST-маршрут удаляется. До завершения переноса они остаются, но **новые не добавляются**.
- **JSON унифицируется на RS-JSON**: чтение через `from_str_secure` / `parse_secure` (ограничения на размер, глубину и повторяющиеся ключи), запись через `rust_json::fast`. `prost` не добавляется в браузерный WASM (размер вырос бы).
- **Исключения (форматы, заданные чужим стандартом, а не наш собственный API)**: ACME, обратные вызовы OAuth/OIDC, вебхуки сторонних сервисов (например, GitHub), проверки работоспособности, раздача статических файлов, OTLP и т. п. Они принимают обычный HTTP, как требует стандарт.
- Эталонные реализации: `RPoem` (`open_runo.admin.v1.Admin`) и `open-easy-web` (`server/src/connect.rs`, `proto/open_easy_web/admin/v1/admin.proto`).
- Примечание: соответствует ли код конкретного репозитория этой политике, зависит от самого репозитория. Этот раздел фиксирует политику и не означает, что код уже изменён.
