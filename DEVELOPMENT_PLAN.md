# Markdownブラウザー 開発計画書

## 1. 背景と目的

本プロジェクトでは、ChromeやFirefoxのようにインターネットをブラウジングしながら、閲覧中のWebページをMarkdownへ変換し、記事・資料・技術文書・学術情報などを構造化して読めるネイティブデスクトップアプリを開発する。

Obsidian Web Clipperは、WebページやハイライトをObsidianのVaultへ保存し、テンプレート、メタデータ、Schema.org、CSSセレクタなどを活用してMarkdownファイル化する思想を持つ。本アプリはその発想を参考にしつつ、単なる保存ツールではなく、通常のWebブラウザ体験にMarkdown変換・Markdown可視化レイヤーを統合した「Markdownブラウザー」として設計する。

ユーザー体験の中心は「ページをクリップする」ことではなく、「Webを巡回しながら、必要なページをMarkdownとして読解・構造化・保存できる」ことである。

参考:

- Obsidian Web Clipper: https://obsidian.md/clipper
- Obsidian Web Clipper Help: https://obsidian.md/help/web-clipper

## 2. プロダクトコンセプト

### 2.1 コア価値

- 通常のブラウザのようにURLを開き、ページ遷移、戻る/進む、タブ、履歴を使える。
- 閲覧中のページをワンクリックでMarkdown表示へ切り替えられる。
- Markdown本文、メタデータ、見出し構造、リンク、引用、画像を分離して把握できる。
- Web表示、Reader表示、Markdown表示、構造表示を切り替えながら読める。
- 変換結果を編集、検索、タグ付け、エクスポートできる。
- ObsidianなどのMarkdownベース知識管理ツールへ渡しやすい形式で保存できる。

### 2.2 想定ユーザー

- Web記事や技術記事をブラウジングしながらMarkdownで読みたい知識労働者
- Obsidian、Logseq、Git管理ノートなどを使うMarkdown利用者
- 調査資料、競合情報、論文、ドキュメントを整理するリサーチャー
- Webページを読みやすい形式で要約、分類、再利用したい開発者・編集者

### 2.3 差別化方針

一般的なWeb Clipperは「保存」が主目的だが、本アプリは「ブラウジング中の読解」「Markdown化された情報の可視化」「情報構造の把握」を重視する。

- ブラウザの主要操作を維持しながら、ページ表示をMarkdown中心に再構成する。
- HTMLとMarkdownの差分・対応関係を見える化する。
- 見出しツリー、リンクマップ、メタデータ、引用候補、画像一覧を同時に確認できる。
- テンプレート適用前後のMarkdownを比較できる。
- 将来的に複数ページを横断したナレッジグラフやタグクラスタを扱う。

## 3. スコープ

### 3.1 MVPで実装する機能

1. アドレスバーによるURL入力
2. ネイティブWebViewによるWebページ表示
3. 戻る/進む/再読み込み
4. タブ管理
5. 閲覧中ページのHTML取得
6. HTML本文抽出
7. HTMLからMarkdownへの変換
8. Web表示/Markdown表示/Reader表示の切り替え
9. Markdownプレビュー
10. メタデータ抽出
11. 見出しアウトライン表示
12. 変換テンプレートの簡易適用
13. アプリ側に永続化する履歴・ブックマーク・保存設定と、セッション内の保存済みMarkdown一覧
14. Markdownファイルのダウンロード

### 3.2 MVPでは扱わない機能

- ブラウザー拡張機能
- Obsidian Vaultへの直接書き込み
- 複数端末同期
- AI要約・AI分類
- 認証付きページの自動取得
- GmailなどGoogle Workspace Web UIのアプリ内ログイン・表示・Markdown化
- Chrome/Firefoxと同等の完全なブラウザエンジン機能
- チーム共有、権限管理

### 3.3 将来拡張

- Chrome/Firefox/Safari拡張
- Obsidian URI連携
- GitHub/Gist/Dropbox連携
- Google Keep連携
- AIによる要約、タグ提案、タイトル整形
- 複数ページのコレクション管理
- Markdown間リンクの可視化
- PDF/EPUB出力

## 4. 主要ユースケース

### 4.1 WebをブラウジングしながらMarkdown表示に切り替える

1. ユーザーがアドレスバーにURLまたは検索語を入力する。
2. アプリがWebページを表示する。
3. ユーザーが通常のブラウザと同じようにリンクを辿る。
4. ユーザーがMarkdown表示へ切り替える。
5. アプリが閲覧中ページの本文、タイトル、著者、公開日、説明文、画像、リンクを抽出する。
6. アプリがMarkdownへ変換し、読みやすいプレビューとして表示する。
7. ユーザーがアウトライン、リンク、メタデータを見ながら内容を把握する。

### 4.2 Web表示とMarkdown表示を行き来する

1. ユーザーがWebページを表示する。
2. 表示モードをWeb、Reader、Markdown、Sourceから選ぶ。
3. Web表示では元ページの見た目を確認する。
4. Markdown表示では本文構造を確認する。
5. Source表示では変換前HTMLや抽出対象を確認する。
6. 必要に応じてMarkdownを編集し、保存する。

### 4.3 テンプレートでノート形式を整える

1. ユーザーが「記事」「技術メモ」「論文」「レシピ」などのテンプレートを選ぶ。
2. 抽出済みメタデータをテンプレート変数へ差し込む。
3. YAML Front Matterと本文を生成する。
4. 出力ファイル名と保存先を指定する。

### 4.4 情報構造を可視化する

1. 閲覧中ページをMarkdownへ変換する。
2. 見出し階層をサイドバーに表示する。
3. 外部リンク、内部リンク、画像、引用、コードブロックを一覧化する。
4. ユーザーが本文と構造を行き来しながら内容を把握する。

### 4.5 Markdownとして保存・エクスポートする

1. ユーザーが閲覧中ページのMarkdown化結果を確認する。
2. 必要に応じてテンプレートを適用する。
3. YAML Front Matterと本文を生成する。
4. Markdownファイルとしてダウンロード、またはローカルライブラリへ保存する。

### 4.6 後で読むリンクをまとめて処理する

1. ユーザーがPCやモバイルで記事リンクをGoogle Keep、ローカルのURLリスト、クリップボード、共有シートなどへ保存する。
2. 本アプリがLink InboxへURL一覧を取り込む。
3. ユーザーが未処理リンクを順番に開く、または一括取得する。
4. アプリがリンク先をWebViewで読み込み、Reader/Markdownへ変換する。
5. ユーザーが不要なリンクを破棄し、有用なページだけローカルフォルダへ保存、タグ付けする。

## 5. 機能要件

### 5.1 ブラウジング

- URL入力
- 検索語入力
- ページ表示
- 戻る/進む
- 再読み込み
- タブ管理
- 履歴
- ブックマーク

ネイティブアプリではWebViewを使って通常のページ表示を行う。MVPではmacOSのWKWebViewを第一ターゲットとし、表示中ページに対してJavaScriptを実行してHTMLを取得し、Reader/Markdown/Source表示へ変換する。

- 表示はネイティブWebViewで行う。
- HTML抽出はWebViewの読み込み完了後に実行する。
- 表示できないページや抽出できないページはエラーを明示する。
- HTML貼り付けによるフォールバック導線を残す。

### 5.2 補助入力

- HTML貼り付け
- ローカルHTMLファイル読み込み
- 既存Markdownファイル読み込み

### 5.3 HTML取得

ネイティブアプリでは、Flutter Webで問題になっていたCORS制約を避け、WebView上で実際に読み込まれたページからHTMLを取得する。

- WKWebViewの読み込み完了イベントを受ける。
- `document.documentElement.outerHTML`をJavaScriptで取得する。
- 取得したHTMLをDart側で解析する。
- ログインページ、動的ページ、CSP制約のあるページでは抽出失敗を警告する。

### 5.4 本文抽出

- `article`、`main`、Open Graph、Schema.orgを優先して本文候補を抽出する。
- ナビゲーション、広告、フッター、サイドバー、スクリプト、スタイルを除去する。
- 本文抽出ロジックは差し替え可能にする。
- 将来的にはReadability系アルゴリズムを導入する。

### 5.5 Markdown変換

- 見出し、段落、リスト、リンク、画像、引用、コードブロック、テーブルをMarkdownへ変換する。
- HTMLタグの変換ルールを明示的に管理する。
- 変換できない要素はHTMLとして残すか、注釈として警告する。
- Markdown出力はCommonMark互換を基本とする。

### 5.6 メタデータ抽出

- title
- description
- author
- published
- modified
- source URL
- canonical URL
- site name
- favicon
- Open Graph画像
- tags

### 5.7 表示モード

- Web: 元ページを表示する。
- Reader: 広告やナビゲーションを除去した読みやすい本文表示。
- Markdown: 変換後Markdownをレンダリングする。
- Editor: 変換後Markdownを編集する。
- Source: 抽出元HTML、抽出済みHTML、変換ログを確認する。

### 5.8 テンプレート

テンプレートは以下のような変数を扱う。

```markdown
---
title: "{{title}}"
source: "{{url}}"
author: "{{author}}"
published: "{{published}}"
tags: [clipping]
---

# {{title}}

{{content}}
```

MVPでは単純な変数置換から始め、将来的に条件分岐、ループ、フィルター、サイト別自動適用へ拡張する。

### 5.9 可視化

- Markdownプレビュー
- 見出しアウトライン
- リンク一覧
- 画像一覧
- コードブロック一覧
- メタデータパネル
- 変換ログ・警告一覧

### 5.10 保存とエクスポート

- ユーザーが明示的に指定したローカルフォルダへのMarkdown保存
- 閲覧履歴はアプリ側データ領域に保存し、削除ボタンで消去できる。
- ブックマークは明示操作で追加し、アプリ側データ領域に保存し、削除ボタンで消去できる。
- 最後に使った保存先フォルダと画像ローカル保存設定をアプリ側データ領域に保存する。
- Markdown化済みページのセッション内一覧表示
- Markdownファイルのダウンロード
- 画像をローカルへ保存し、Markdown内の画像リンクを相対パスへ書き換える。
- 「全てローカルに保存する」チェックボックスで画像ローカル化の有無を切り替える。
- WebViewのCookie、キャッシュ、LocalStorageを明示操作で削除できる。
- JSON形式でのプロジェクトエクスポート
- 将来的にObsidian URI、File System Access API、Git連携を検討する。

### 5.11 Link Inbox

本アプリの情報収集ワークフローでは、Google Keep、クリップボード、ローカルファイル、共有拡張、ブラウザ拡張などを「リンク投入元」として扱い、アプリ内にLink Inboxを用意する。ユーザーはPCやモバイルで「後で読む」と思った記事リンクを任意の受け皿に保存し、後から本アプリでまとめて読み込み、Markdown化、分類、保存する。

Link Inboxの役割:

- URLを一時保存する。
- 未読、処理済み、保存済み、失敗などの状態を管理する。
- URLを一括で開き、Reader/Markdown表示へ変換する。
- タイトル、サイト名、取得日時、タグ、メモを付与する。
- 変換済みMarkdownと取得可能な画像をローカル、将来的にObsidianへ保存する。

初期入力経路:

- クリップボードからURLを取り込む。
- 複数URLをテキスト貼り付けで取り込む。
- ローカルのMarkdown/JSON/CSVファイルからURL一覧を取り込む。
- ローカルの「read-later」Markdown/JSON/CSVファイルからURL一覧を取り込む。

将来入力経路:

- macOS Share Extension
- iOS/Android共有シート
- Chrome/Firefox/Safari拡張
- Google Keepからの手動エクスポートまたは共有導線
- Google Tasks、Google Docs、Google SheetsなどからエクスポートしたURLリスト

### 5.12 Googleサービスの扱い

Googleサービスは必要に応じて通常URLとしてWebViewで開く情報収集元として扱う。Google Drive APIによるバックアップ・同期は実装しない。Google KeepとGoogle Photosの専用ボタンは設けず、ユーザーが通常のURL入力、ブックマーク、履歴から開く。Gmailは対応ブラウザ判定やメール本文の取り扱いリスクが高いため対象外とする。

#### Google Drive

Google Drive API連携は削除する。必要であれば、ユーザーがローカル保存フォルダをGoogle Drive同期フォルダ配下に指定することで、OS/Driveクライアント側の同期に任せる。

想定機能:

- Google Drive APIは使用しない。
- OAuth認証は行わない。
- 保存先フォルダとしてGoogle Drive同期フォルダを選べる。
- Drive連携が必要な場合はGoogle Driveデスクトップアプリの同期機能に任せる。

#### Google Keep

Google Keepは「後で読むリンクを一時的に置く場所」として有用なので、アプリ内WebViewでブラウジングできる導線を用意する。ただし、DriveのようなAPI同期先としては慎重に扱う。公式Keep APIは主にGoogle Workspaceの管理者・エンタープライズ用途を想定しており、個人ユーザーのKeepメモを自由に同期する一般的なノートAPIとしては扱いにくい。

想定機能:

- Google Keepを通常URLまたはブックマークからWebViewで開く。
- Keep上のリンクをユーザーがコピーし、Link Inboxへ貼り付ける運用をサポートする。
- KeepからGoogle Docsへコピーしたリンク集をDrive経由で取り込む運用を検討する。
- Workspace環境で許可される場合のみKeep API連携を検討する。
- Keep連携は「必須機能」ではなく「リンク投入元の一例」として扱う。

#### Google Photos

Google PhotosはAPI連携ではなく、アプリ内WebViewでブラウジングする。画像そのものの同期やバックアップ先としては扱わず、写真ページやアルバムページを必要に応じて参照する導線に限定する。

想定機能:

- Google Photosを通常URLまたはブックマークからWebViewで開く。
- Photos内の共有リンクや説明テキストを必要に応じてコピーし、Markdown編集に利用する。
- Google Photos APIによる写真データ同期はMVPでは扱わない。

#### Gmail

Gmailは対象外とする。GmailのWeb UIをアプリ内WebViewでログイン・閲覧・Markdown化する設計は、Googleの対応ブラウザ判定や認証制約に影響されやすく、メール本文の取り扱いとしてもリスクが高い。

## 6. 非機能要件

### 6.1 パフォーマンス

- 1ページあたり1MB程度のHTMLを快適に処理できる。
- 変換処理はUIスレッドを極力ブロックしない。
- 大きなHTMLは段階的に解析し、変換中ステータスを表示する。

### 6.2 プライバシー

- 入力HTMLと変換結果は原則ローカルに保持する。
- 外部APIを使う場合、保存しない設計にする。
- 外部AIや外部保存先への送信は明示的な操作がある場合だけ行う。

### 6.3 信頼性

- 取得、抽出、変換、保存の各段階でエラーを分離して表示する。
- 元HTMLを保持し、再変換できるようにする。
- 変換ルールの変更で既存データが壊れないよう、変換バージョンを保存する。

### 6.4 アクセシビリティ

- キーボード操作
- セマンティックなUI構造
- 十分なコントラスト
- スクリーンリーダー向けラベル
- プレビューとエディタのフォーカス移動

## 7. 技術方針

### 7.1 フロントエンド

- Flutter desktop
- macOSを初期ターゲットにする。
- WebView: `webview_flutter` + `webview_flutter_wkwebview`
- Dart
- Material 3またはカスタムデザインシステム
- 状態管理: Riverpodを第一候補
- ルーティング: go_router
- 永続化: ローカルファイル、SQLite、Hive/Isar系ローカルストレージ

### 7.2 Markdown関連

候補ライブラリ:

- `markdown`: Markdownパース・HTML変換
- `flutter_markdown`: Markdownプレビュー
- 高機能Markdownエディタ: 必要に応じてネイティブ埋め込みまたは専用編集コンポーネントを検討

Flutterネイティブな編集体験を優先する場合は、MVPでは通常のテキストエリア相当から開始する。

### 7.3 HTML解析

候補:

- Dartの`html`パッケージでDOM解析
- 独自のHTML-to-Markdown変換レイヤー
- バックエンド側でReadabilityやTurndown相当を利用する構成

MVPではWebViewから取得したHTMLをDartの`html`パッケージで解析し、本文抽出とMarkdown変換を行う。必要になれば、将来的にReadability系アルゴリズムやサイト別抽出ルールを追加する。

### 7.4 バックエンド

MVPではバックエンドを必須にしない。WebViewから直接HTMLを取得し、変換・保存はローカルで完結させる。

候補:

- ローカルファイル保存
- Obsidian Vault連携
- 将来的な同期API
- 将来的なAI要約API

API例:

- `POST /summarize`: Markdownを受け取り要約を返す
- `POST /classify`: Markdownを受け取りタグ候補を返す

### 7.5 データモデル

```dart
class BrowserTab {
  final String id;
  final String title;
  final Uri? currentUrl;
  final List<Uri> backStack;
  final List<Uri> forwardStack;
  final PageViewMode viewMode;
  final PageDocument? document;
}
```

```dart
enum PageViewMode {
  web,
  reader,
  markdown,
  editor,
  source,
}
```

```dart
class PageDocument {
  final String id;
  final String title;
  final Uri? sourceUrl;
  final String? canonicalUrl;
  final String rawHtml;
  final String extractedHtml;
  final String markdown;
  final PageMetadata metadata;
  final List<PageAsset> assets;
  final List<ConversionWarning> warnings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String converterVersion;
}
```

```dart
class LinkInboxItem {
  final String id;
  final Uri url;
  final String? title;
  final String? source;
  final LinkInboxStatus status;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? processedAt;
}
```

```dart
enum LinkInboxStatus {
  unread,
  opened,
  converted,
  saved,
  failed,
  archived,
}
```

```dart
class PageMetadata {
  final String? description;
  final String? author;
  final DateTime? publishedAt;
  final DateTime? modifiedAt;
  final String? siteName;
  final List<String> tags;
}
```

## 8. UI構成

### 8.1 画面構成

- Browser Workspace画面
- タブバー
- アドレスバー
- ナビゲーションツールバー
- Web表示ビュー
- Reader表示ビュー
- Markdown表示ビュー
- Markdownエディタ
- アウトライン/メタデータサイドバー
- 履歴・ブックマーク・保存済みMarkdownライブラリ
- テンプレート管理画面
- 設定画面

### 8.2 ブラウザ画面のレイアウト

デスクトップでは3ペイン構成を基本にする。

- 上: タブバー、戻る/進む、再読み込み、アドレスバー、表示モード切り替え
- 左: 履歴、ブックマーク、保存済みMarkdown、検索
- 中央: Web/Reader/Markdown/Editor/Sourceの現在表示
- 右: メタデータ、アウトライン、リンク、画像、警告

モバイルではタブ切り替えにする。

- Web
- Reader
- Markdown
- Outline
- Metadata

### 8.3 操作導線

1. URLまたは検索語をアドレスバーに入力する。
2. Webページを表示する。
3. 必要に応じてリンク遷移、戻る/進む、タブ追加を行う。
4. Markdown表示またはReader表示へ切り替える。
5. メタデータ、アウトライン、リンク一覧を確認する。
6. 必要に応じてMarkdown編集、テンプレート適用、保存またはダウンロードを行う。

## 9. アーキテクチャ

### 9.1 レイヤー

- Presentation: Flutter UI、画面、コンポーネント
- Application: ユースケース、状態管理、コマンド
- Domain: BrowserTab、PageDocument、テンプレート、変換ルール
- Infrastructure: HTML取得、Storage、Markdown変換、外部API

### 9.2 主要モジュール

- `browser_shell`: タブ、アドレスバー、ナビゲーション
- `web_page_view`: Web表示
- `reader_view`: Reader表示
- `markdown_viewer`: Markdown表示
- `markdown_editor`: Markdown編集
- `link_inbox`: 後で読むURLの取り込み、状態管理、一括処理
- `html_fetcher`: HTML取得
- `html_extractor`: 本文抽出
- `html_to_markdown`: Markdown変換
- `template_engine`: テンプレート適用
- `page_repository`: 履歴、ブックマーク、保存済みMarkdown一覧
- `app_state_store`: アプリ側データ領域のJSON永続化
- `link_inbox_repository`: Link Inbox保存・検索・インポート
- `local_archive`: Markdownと画像アセットのローカル保存
- `exporter`: ファイル出力
- `web_sources`: Keep/Photosを含む任意URLのWebViewブラウジング導線

### 9.3 データフロー

```text
Address bar / Link navigation
  -> Open page in browser shell
  -> Fetch/Parse HTML
  -> Extract metadata
  -> Extract readable content
  -> Convert to Markdown
  -> Render as Reader/Markdown
  -> Inspect outline/links/assets
  -> Edit/Apply template
  -> Save/Export if needed
```

ローカル保存時:

```text
Markdown document
  -> User selects local save folder
  -> Optionally download image assets
  -> Rewrite image references to local relative paths
  -> Write Markdown and assets to the selected folder
```

Link Inbox処理時:

```text
Keep / clipboard / local URL list / share extension
  -> Import URLs into Link Inbox
  -> User opens or batch-processes unread links
  -> WebView loads each URL
  -> Convert to Reader/Markdown
  -> Save useful pages and archive the rest
```

## 10. 開発フェーズ

### Phase 0: 企画・検証

期間目安: 1週間

- 要件整理
- 競合・参考機能の確認
- Flutter desktopでのブラウザシェル実装検証
- macOS WKWebViewでのページ表示検証
- WebViewからのHTML抽出検証
- Markdownプレビュー検証
- ネイティブアプリのSandbox/ネットワーク権限確認

成果物:

- 本計画書
- 技術検証メモ
- 簡易プロトタイプ

### Phase 1: MVP基盤

期間目安: 2週間

- Flutterプロジェクト作成
- macOSターゲット作成
- ブラウザシェル実装
- タブバー実装
- アドレスバー実装
- 戻る/進む/再読み込み実装
- ネイティブWebView表示ビュー実装
- 表示モード切り替え実装
- 基本Markdown変換
- Markdown表示
- 履歴とブックマークのアプリ側永続化
- 最後に使った保存先フォルダと保存設定の復元
- 履歴、ブックマーク、WebViewデータの削除操作

完了条件:

- URL入力からページ表示まで一通り動く。
- 表示中ページをMarkdown表示へ切り替えられる。
- ブラウザ履歴を使って戻る/進むができる。

### Phase 2: WebView HTML抽出と本文抽出

期間目安: 2週間

- WebView読み込み完了後のHTML抽出
- メタデータ抽出
- 本文抽出ロジック
- 変換警告表示
- 取得失敗時のエラーハンドリング
- 表示不可ページや抽出不可ページのフォールバック

完了条件:

- 複数の一般的な記事サイトでタイトル、本文、リンク、画像を抽出できる。
- WebView表示、Reader表示、Markdown表示を同じページから切り替えられる。

### Phase 3: テンプレートと可視化

期間目安: 2週間

- テンプレート管理
- YAML Front Matter生成
- アウトライン表示
- リンク一覧
- 画像一覧
- コードブロック一覧
- ブックマーク
- 保存済みMarkdownライブラリ
- ダウンロード機能

完了条件:

- ユーザーがテンプレートを選び、Markdown出力形式を調整できる。
- 閲覧中ページのMarkdown構造情報をサイドバーで確認できる。

### Phase 4: 品質改善

期間目安: 2週間

- 変換精度改善
- ブラウジング操作の安定化
- レスポンシブ対応
- アクセシビリティ確認
- パフォーマンス改善
- テスト整備
- エクスポート形式の安定化

完了条件:

- 代表的なHTMLサンプルで変換結果が安定する。
- デスクトップとモバイルで主要操作が破綻しない。

### Phase 5: Link Inboxとローカルアーカイブ

期間目安: 2週間

- Link Inbox画面
- クリップボードからURL取り込み
- 複数URL貼り付けインポート
- URLの未読/処理済み/保存済み状態管理
- ローカル保存先フォルダ指定
- 現在のMarkdownをローカルフォルダへ保存
- 画像をローカル保存するオプション
- Markdown内の画像URLをローカル相対パスへ書き換える
- ローカルURLリスト読み込み
- Keep/Photosを含む任意URLを通常のアドレスバー、履歴、ブックマークから開く導線
- 保存失敗・画像取得失敗時のエラーハンドリング

完了条件:

- ユーザーがURLリストをLink Inboxへ取り込める。
- Inbox内のURLを順番に開いてMarkdown化できる。
- ユーザーがMarkdownを指定フォルダへ保存できる。
- 取得可能な画像をローカルアセットとして保存できる。
- Keep/Photosを含む任意URLをアプリ内WebViewで開ける。

### Phase 6: 拡張機能検討

期間目安: 以降継続

- ブラウザー拡張
- Obsidian URI連携
- AI要約
- 複数ページコレクション
- ナレッジグラフ
- セッション復元

## 11. テスト計画

### 11.1 ユニットテスト

- HTMLパーサー
- 本文抽出
- HTML-to-Markdown変換
- テンプレート変数置換
- ファイル名生成
- メタデータ正規化

### 11.2 ウィジェットテスト

- アドレスバー
- タブバー
- ナビゲーションボタン
- 表示モード切り替え
- エディタ/プレビュー切り替え
- サイドバー
- テンプレート選択
- 保存済み一覧

### 11.3 結合テスト

- URL入力からWeb表示まで
- Web表示からMarkdown表示切り替えまで
- リンク遷移から戻る/進むまで
- テンプレート適用からダウンロードまで
- 保存済みMarkdownの再編集

### 11.4 サンプルデータ

以下のHTMLをテストフィクスチャとして用意する。

- 一般記事
- 技術ドキュメント
- ブログ
- 論文ページ
- レシピ
- テーブルを含むページ
- コードブロックを含むページ
- 画像中心ページ
- 不正なHTML

## 12. リスクと対策

| リスク | 影響 | 対策 |
| --- | --- | --- |
| WebViewで表示できないページがある | ブラウジング体験が限定される | エラーを明示し、外部ブラウザで開く導線を用意する |
| JavaScriptによるHTML抽出が失敗する | Markdown化できるページが限定される | HTML貼り付けフォールバックと抽出警告を用意する |
| サイトごとにHTML構造が違う | 本文抽出精度が不安定 | Readability系ロジックとサイト別ルールを併用する |
| Markdown変換が崩れる | 保存品質が下がる | 変換警告、元HTML保持、テストフィクスチャを整備する |
| Flutterの長文エディタ体験が弱い | 長文編集がしづらい | 必要に応じてCodeMirror/Monaco相当のネイティブ埋め込みを検討する |
| 画像の扱いが難しい | Markdown再利用性が下がる | 取得可能な画像はローカル保存し、失敗時は元URLを残す |
| 認証付き画像や動的画像を保存できない | 完全ローカル化できないページがある | 保存ログ・警告を表示し、元URL参照を維持する |
| ローカルフォルダ権限が不足する | 保存に失敗する | ユーザー選択フォルダへの書き込み権限を使い、失敗時に再選択を促す |
| GmailなどのWeb UIがアプリ内WebViewを拒否する | Googleサービスのブラウジングが不安定になる | Gmail等のWeb UI対応は対象外とする |
| 著作権・利用規約への配慮 | 不適切な利用につながる | 個人保存・引用補助を前提にし、再配布機能は慎重に設計する |

## 13. 初期ディレクトリ案

```text
lib/
  main.dart
  app.dart
  features/
    browser_shell/
    web_page_view/
    reader_view/
    markdown_preview/
    markdown_editor/
    template_editor/
    saved_pages/
  domain/
    browser_tab.dart
    page_document.dart
    page_metadata.dart
    conversion_warning.dart
    markdown_template.dart
  infrastructure/
    html_fetcher/
    html_extractor/
    html_to_markdown/
    storage/
    exporter/
  shared/
    widgets/
    theme/
    utils/
test/
  fixtures/
  unit/
  widget/
  integration/
```

## 14. MVP成功基準

- アドレスバーからURLを開き、ページを表示できる。
- 戻る/進む/再読み込み/タブ追加の基本操作ができる。
- 表示中ページをMarkdown表示へ切り替えられる。
- Markdown表示結果を手動編集できる。
- タイトル、URL、説明文、著者、公開日などのメタデータを確認できる。
- 見出しアウトラインとリンク一覧で情報構造を把握できる。
- Markdownファイルと取得可能な画像を指定ローカルフォルダへ保存できる。
- 代表的な10種類以上のHTMLサンプルで変換処理がクラッシュしない。

## 15. 次のアクション

1. Link Inbox画面を実装する。
2. クリップボード/テキスト貼り付けから複数URLを取り込めるようにする。
3. Inbox内URLを順番に開き、Markdown化できる導線を作る。
4. ローカル保存ログと画像取得失敗警告を表示する。
5. 保存済みローカルMarkdownライブラリを実装する。
