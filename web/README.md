# open-english-pc / web

**引っ越しました / We have moved — https://maid-cafe.tokyo**

日本語: この画面は **https://maid-cafe.tokyo** に引っ越しました。`index.html` は、引っ越しの案内(日本語・英語)と、新しい Web 版へのリンクだけです。古い画面(`app.js`・`style.css` など)は削除しました(履歴は git に残っています。復元は `git log -- web/app.js` で探せます)。

English: This client has moved to **https://maid-cafe.tokyo**. `index.html` now contains only the move notice (Japanese and English) and a link to the new web version. The old screens (`app.js`, `style.css`, …) were removed; they remain in git history.

- `index.html` … 引っ越しの案内とリンク / the move notice and link
- `version.json` … バージョン(Android の Gradle が読む) / version (read by the Android Gradle build)
- `icons/` … アイコン / icons

Android 版(`mobile/android`)は、ビルド時にこの `web/` を `assets/webroot/` へ同期します。 / The Android build syncs this `web/` into `assets/webroot/`.
