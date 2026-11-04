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

### Deutsch (KI-Übersetzung, redaktionell überarbeitet; noch nicht von Muttersprachlern geprüft)
- **REST wird vollständig abgeschafft; neue APIs entstehen nicht mehr als REST.** APIs, die aus dem Browser oder per `curl` aufgerufen werden, verwenden **unäre Connect-Aufrufe** (`POST /<Paket>.<Service>/<Methode>`, `content-type: application/json`, JSON-Body). Zwischen Diensten kommen **gRPC bzw. gRPC-web** zum Einsatz, im selben Stil wie die Admin-API von RPoem (`open_runo.admin.v1.Admin`). Streaming wird erst ergänzt, wenn es tatsächlich gebraucht wird.
- **Bestehende REST-Endpunkte werden schrittweise umgestellt, und zwar immer dann, wenn man ohnehin an ihnen arbeitet.** Sobald ein Endpunkt umgestellt ist, wird die alte REST-Route entfernt. Bis zum Abschluss der Migration bleiben die übrigen bestehen, es werden aber **keine neuen mehr hinzugefügt**.
- **JSON wird einheitlich über RS-JSON verarbeitet**: Gelesen wird mit `from_str_secure` bzw. `parse_secure` (mit Obergrenzen für Größe, Verschachtelungstiefe und doppelte Schlüssel), geschrieben mit `rust_json::fast`. `prost` wird nicht in das Browser-WASM aufgenommen, da es die Datei vergrößern würde.
- **Ausnahmen (Schnittstellen, deren Form ein fremder Standard vorgibt und die nicht zu unserer eigenen API gehören)**: ACME, OAuth/OIDC-Callbacks, Webhooks von Drittanbietern (z. B. GitHub), Health-Checks, die Auslieferung statischer Dateien, OTLP und Ähnliches. Diese nehmen, wie vom jeweiligen Standard verlangt, gewöhnliches HTTP entgegen.
- Referenzimplementierungen: `RPoem` (`open_runo.admin.v1.Admin`) und `open-easy-web` (`server/src/connect.rs`, `proto/open_easy_web/admin/v1/admin.proto`).
- Hinweis: Ob der Code eines einzelnen Repositorys diese Richtlinie bereits erfüllt, hängt vom jeweiligen Repository ab. Dieser Abschnitt dokumentiert lediglich die Richtlinie; er besagt nicht, dass der Code schon angepasst wurde.

### Русский (перевод выполнен с помощью ИИ и отредактирован; носителями языка пока не проверен)
- **От REST мы полностью отказываемся; новые API больше не создаются в стиле REST.** API, к которым обращаются из браузера или через `curl`, используют **унарные вызовы Connect** (`POST /<пакет>.<Service>/<Method>`, `content-type: application/json`, тело запроса — JSON). Для взаимодействия между сервисами применяются **gRPC и gRPC-web** — в том же стиле, что и административный API RPoem (`open_runo.admin.v1.Admin`). Потоковая передача данных добавляется лишь тогда, когда в ней действительно возникает необходимость.
- **Существующие REST-эндпоинты переводятся поэтапно — по мере того, как с ними приходится работать.** После перевода старый REST-маршрут удаляется. Пока миграция не завершена, оставшиеся эндпоинты сохраняются, но **новые не добавляются**.
- **Работа с JSON унифицирована на основе RS-JSON**: чтение — через `from_str_secure` или `parse_secure` (с ограничениями на размер, глубину вложенности и повторяющиеся ключи), запись — через `rust_json::fast`. `prost` в браузерный WASM не включается, поскольку это увеличило бы размер файла.
- **Исключения (интерфейсы, форму которых определяет чужой стандарт, а не наш собственный API)**: ACME, обратные вызовы OAuth/OIDC, вебхуки сторонних сервисов (например, GitHub), проверки работоспособности, раздача статических файлов, OTLP и тому подобное. Такие интерфейсы принимают обычный HTTP, как того требует соответствующий стандарт.
- Эталонные реализации: `RPoem` (`open_runo.admin.v1.Admin`) и `open-easy-web` (`server/src/connect.rs`, `proto/open_easy_web/admin/v1/admin.proto`).
- Примечание: соответствует ли код конкретного репозитория этой политике, зависит от самого репозитория. Данный раздел лишь фиксирует политику и не означает, что код уже изменён.
