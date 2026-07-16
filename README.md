# Markdown Browser

Markdown Browserは、通常のブラウザのようにWebページを開きながら、表示中ページをMarkdownへ変換して読解・整理・保存するためのネイティブデスクトップアプリです。

Obsidian Web Clipperの「WebページをMarkdownとして扱う」発想を参考にしつつ、単なるクリッパーではなく、ブラウジング体験そのものにReader表示、Markdown表示、メタデータ確認、ローカル保存を組み込むことを目指しています。

現在はmacOS、Windows、Linux向けのプロトタイプです。各OSのネイティブWebViewで読み込んだページHTMLをJavaScriptで取得してMarkdownへ変換します。

## 主な機能

- URL入力、検索語入力、戻る、進む、再読み込み
- タブ管理とタブを閉じる操作
- Web / Reader / Markdown / Editor / Source表示の切り替え
- 読み込み済みページHTMLからのMarkdown変換
- タイトル、説明、著者、公開日、サイト名などのメタデータ抽出
- 見出し、リンク、画像、変換警告の確認
- 履歴、ブックマーク、ホームページ、保存設定のアプリ内永続化
- 左ペインのBookmarks / History / Saved切り替え表示
- 右ペインのメタデータ表示切り替え
- 右クリックリンクの「新しいタブで開く」
- ローカルのMarkdown・テキストファイルの読み込み
- Markdownの編集とローカルフォルダへの保存
- 画像をローカルに保存し、Markdown内リンクを相対パスへ書き換えるオプション
- WebViewのCookie、キャッシュ、LocalStorage削除
- ホームページ設定。初期値は `https://www.google.com`

## 想定する使い方

1. Web記事、技術文書、調査資料などをアプリ内で開く。
2. 必要に応じてWeb表示からReader表示やMarkdown表示へ切り替える。
3. 見出し、リンク、画像、メタデータを確認しながら内容を把握する。
4. 必要なページだけMarkdownとして編集する。
5. 指定したローカルフォルダへMarkdownと画像アセットを保存する。

ツールバーのファイルを開くボタンから、既存の `.md`、`.markdown`、`.mdown`、`.mkd`、`.txt` ファイルを読み込めます。Markdown内の相対画像リンクは、読み込んだファイルがあるフォルダを基準に表示します。

Google KeepやGoogle Photosなども、専用API連携ではなく通常のURLとしてWebViewで開く方針です。GmailのWeb UI表示やメール本文のMarkdown化は対象外です。

## インストール

GitHub Releasesで配布されているmacOS向けZIPをダウンロードし、展開した `.app` を起動してください。

現在の簡易配布版は署名・notarizationを行っていません。そのためmacOS Gatekeeperにより警告が表示される場合があります。

## 開発環境での実行

Flutter SDKが必要です。

```sh
flutter pub get
flutter run -d macos
```

LinuxではWebKitGTK 4.1の開発パッケージも必要です。Ubuntu/Debianでは次のようにインストールしてから起動します。

```sh
sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev
flutter pub get
flutter run -d linux
```

## 検証

```sh
flutter analyze
flutter test
flutter build macos
flutter build linux
```

## 配布用ZIPの作成

署名なしのmacOS ZIPを作る簡易スクリプトを用意しています。

```sh
./deploy.sh macos
```

生成物は `dist/` に出力されます。

```text
dist/markdown_browser-macos-vX.Y.Z-unsigned.zip
```

このZIPは署名・notarizationされていません。一般配布を本格化する場合は、Apple Developer IDによる署名、Hardened Runtime、notarization、stapleを行うことを推奨します。

## ワークスペースとローカル保存

ツールバーのフォルダボタンから固定ワークスペースを選び、`Save`を押すと現在のMarkdownを保存します。iCloud Drive、Google Drive、Dropboxなどの同期フォルダをワークスペースに選ぶことで、アプリ固有のクラウドAPIを使わずにデータを同期できます。

初回選択時に以下の構成を作成します。

```text
MarkdownBrowser/
├── Articles/
│   ├── article.md
│   └── article_assets/
└── MarkdownBrowser Data/
    ├── workspace.json
    ├── bookmarks/
    ├── history/
    └── devices/
```

- Markdownと画像は`Articles`へ保存します。
- ブックマークは1件ずつ独立したJSONとして保存し、クラウド競合を抑えます。
- 履歴は端末別JSONへ保存し、端末間で同じファイルを同時編集しない構成です。
- ホームページと`Local images`設定は`workspace.json`へ保存します。
- Cookie、WebViewキャッシュ、ログイン状態はワークスペースへ保存しません。
- macOSではSecurity-Scoped Bookmarkを使い、再起動後に選択済みワークスペースへのアクセス権を復元します。

`Local images`を有効にすると、取得可能な画像をMarkdownファイル横のアセットフォルダへ保存し、Markdown内の画像リンクをローカル相対パスへ書き換えます。

既存のMarkdownファイルを後から画像ローカル化する場合は、データ操作画面の`Localize Markdown images`を使用します。

認証が必要な画像、ホットリンクを拒否する画像、JavaScriptで動的生成される画像は保存できない場合があります。その場合は元URLを維持します。

## アプリ内データ

Application Supportにはワークスペースを復元するためのローカル設定と互換用データも保持します。共有対象のブックマーク、履歴、ホームページ、保存設定はワークスペース側にも保存されます。

- 履歴
- ブックマーク
- ホームページURL
- 最後に使ったワークスペースの復元情報
- `Local images`設定

ツールバーのデータ操作ボタンから、履歴、ブックマーク、保存済み一覧、ワークスペース設定、WebViewデータを削除できます。

WebViewデータを削除するとCookie、キャッシュ、LocalStorageが消えるため、ログイン済みサービスでは再ログインが必要になる場合があります。ユーザーが保存したMarkdownファイルや画像アセットは削除されません。

## 現在の制限

- デスクトップOSごとにWebViewエンジンと必要なシステム依存が異なります。Linux版にはWebKitGTK 4.1が必要です。
- ChromeやFirefoxと同等の完全なブラウザ機能は目指していません。
- WebViewで表示できないページや、JavaScript・CSP・ログイン状態に依存するページはMarkdown化できない場合があります。
- GmailなどGoogle Workspace Web UIの閲覧・Markdown化は対象外です。
- Google Drive API、Google Keep API、Google Photos APIによる同期やバックアップは実装していません。
- AI要約、タグ提案、複数端末同期、Obsidian Vaultへの直接書き込みは未実装です。

## 開発方針

このアプリは、情報収集とMarkdownベースの知識整理をつなぐローカルファーストなブラウザを目指しています。

基本方針:

- Webページの閲覧、読解、Markdown化を同じ画面で行う。
- 外部APIやクラウド保存に依存せず、ローカルで完結させる。
- ユーザーが明示的に指定したフォルダにだけMarkdownと画像を保存する。
- 履歴やブックマークなどのブラウザ状態はアプリ側に保存し、削除操作を提供する。
- Obsidian、Logseq、Git管理ノートなど、Markdownベースの環境へ渡しやすい形式を保つ。

詳細な設計背景は[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)を参照してください。

## ライセンス

MIT Licenseです。詳細は[LICENSE](LICENSE)を参照してください。
