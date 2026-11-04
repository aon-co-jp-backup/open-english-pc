# PORTING — open-english-pc

## 由来

[`open-english`](https://github.com/aon-co-jp/open-english) のクライアント
（デスクトップ／タブレット／モバイル）を本体から分離するために新設
（2026-09-10）。本体はデモ環境（`easy-web.tokyo/open-english.tokyo/demo`）と
配信サーバー `open-english-server` を持ち続ける。

## 移設チェックリスト

- [x] リポジトリ新設・モノレポ骨組み（`pc/` `tablet/` `mobile/`）
- [x] `open-english/README.md` から本リポジトリ（および releases/latest）への静的リンク
- [x] **Phase 2**: クライアント資産を `git filter-repo` で履歴付き移設（2026-09-10）
      - `web/` ← `index.html` `style.css` `app.js` `auto-update.js` `version.json`
        `manifest.json` `exam-prep-questions.json` `sw.js` `facebook.html`
        `qr-confirm.html` `vault.html` `icons/`
      - `mobile/android/` ← 本体 `android/`
      - `--allow-unrelated-histories` で骨組みへマージ、203 コミット
- [x] **Phase 2b**（2026-09-10）: 本体 `open-english` を submodule `client/`
      （= このリポジトリ）参照へ切替
      - `.gitmodules`: `client` → `open-english-pc`（shallow）
      - `server/src/main.rs`: 起動時に `client/web/` を配信ルートへミラーする
        `sync_client_from_submodule()` を追加。インストール済みコピーでは no-op
      - ルート直下のクライアントファイルを untrack + `.gitignore`
      - `.github/workflows/release.yml`: `submodules: recursive` ＋
        `client/web/` から同梱
      - `installer/windows/open-english.iss`: `Source` を `..\..\client\web\` へ
        （従来同梱漏れの `sw.js` / `*.html` / `world-language-*.json` も追加）
      - **バージョンの正本は `web/version.json`**（現在 0.8.1）。リリース時は
        ここを bump → コミット → 本体で `git add client` → 本体で `vX.Y.Z` タグ
      - 検証: 本体 `cargo build --release` OK、開発機＋VPS(:8104/:8107)で
        `client sync: mirrored 15 entries` ＋ 主要静的パス 200 を E2E 確認
      - Windows Inno Setup ビルドも検証済み（2026-09-11、v0.8.2）: CI success、
        `open-english-installer.exe` を開発機でサイレントインストール →
        `client/web/` 由来の全 14 ファイル（従来 .iss 同梱漏れの sw.js /
        *.html / world-language-*.json 含む）＋ icons/ が配置、自動起動した
        サーバーが :4601 で全静的パス 200・version.json 0.8.2 を確認
- [x] **Phase 3**（2026-09-10、open-english `060378b`、v0.8.1 で配布）:
      定期ループを2フェーズ化。(1) 起動直後のメンテナンス表示中は **30 秒間隔**で
      `self_update` ＋ `component_update::check_and_apply_all()`（本体＋
      aruaru-llm＋aruaru-db）、最大 `OPEN_ENGLISH_MAINTENANCE_FAST_TICKS` 回
      （既定 6＝約3分、0 で無効）。(2) 以降 30 分間隔。VPS で起動＋30 秒後の
      `maintenance-window update check (1/6, every 30s)` ログ発火を E2E 確認
- [x] pc / tablet / mobile それぞれのビルド・インストーラー構成（完了 2026-09-11）
      - [x] 共通ビルド基盤の設計 `BUILD.md`（web/ と web/version.json を単一の正本、
            差分はパッケージングのみ、リリースは open-english の vX.Y.Z タグ1系統）
      - [x] Android: 単一 Gradle プロジェクトを product flavor `phone` / `tablet` に分割
            （tablet は applicationId `.tablet` サフィックス）、versionName を
            web/version.json から自動取得
      - [x] `open-english/.github/workflows/release.yml` に `build-android` ジョブ
            （Release 署名鍵があれば `assemblePhoneRelease`/`assembleTabletRelease`、
            無ければ `assemblePhoneDebug`/`assembleTabletDebug` にフォールバック）
      - [x] **Android リリース署名鍵**を生成し `aon-co-jp/open-english` の Actions
            シークレット（`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` /
            `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`）に登録。alias
            `open-english-release`、RSA 4096、有効期限 30 年（2056-09 まで）。
            `.jks` 本体とパスワードはユーザーへ送付済み（CI 側はファイルを保持しない）。
            `workflow_dispatch` で `assemble*Release` 実走・success、生成 APK に
            APK Signing Block v2/v3 が存在することをバイナリ解析で確認
      - [x] **`tablet` flavor のレイアウト最適化**: `app/src/tablet/res/layout/
            activity_main.xml` を新設。操作パネルを中央寄せ 600dp 幅カラムへ
            （600dp 未満では実質全幅）。ID・要素は phone 版と完全一致、
            `MainActivity.kt`（`findViewById` のみに依存）はそのまま両 flavor で共用
      - [x] **`pc/` のデスクトップ固有補助**: 検討の結果、追加の構成は不要と判断。
            デスクトップの実体は `open-english` 本体の `open-english-server` ＋
            `client/web/`（Phase 2b で完了済み）であり、`open-english-pc/pc/` 側に
            重複したビルド設定を持たせる理由がない（`BUILD.md` の pc/ 節に明記）。
            具体的な要件が出た時点で追加する

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
