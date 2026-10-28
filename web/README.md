# open-english-pc / web

**この画面は https://maid-cafe.tokyo と同じ画面です(融合済み) / This is the same screen as https://maid-cafe.tokyo (fused).**

日本語: 画面(`index.html`・`app.js`・`style.css` など)の**正本は `maid-cafe-english` の `web/`** です。PC・タブレット・スマホのアプリは、それをここ(`web/`)と Android の同梱コピー(`mobile/android/.../assets/webroot/`)へ同期して同梱します。画面を直すときは `maid-cafe-english` で直し、`scripts/sync-web.sh` で取り込んでください。アプリには、`aruaru-llm`(`open-cuda` 内蔵)・`open-easy-web` なども、インストーラーが一緒に入れます(`maid-cafe-english` の `installer/`)。

English: The **canonical source of the screen is `web/` in `maid-cafe-english`**. The PC / tablet / phone apps bundle it here (`web/`) and in the Android webroot copy. Fix the screen in `maid-cafe-english`, then run `scripts/sync-web.sh`. The installer also installs `aruaru-llm` (with `open-cuda`) and `open-easy-web` together.

- `version.json` … バージョン(Android の Gradle が読む) / version (read by the Android Gradle build)
