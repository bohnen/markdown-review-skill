# markdown-review

Markdownを **markdownlint + textlint** で機械レビューし、さらに **日本語の技術文書の文章規範** に照らして推敲するClaude Codeプラグイン。文書種別でtextlintのルールを使い分ける。

- **technical（一般の技術文書）** … textlint標準ルール（`preset-ja-technical-writing` + `preset-jtf-style` を既定値で）。箇条書きは「である調」。
- **blog（ブログ等）** … `no-mix-dearu-desumasu` を `preferInList: "ですます"` に設定。本文および箇条書きを「ですます調」で統一し、親しみやすさを優先。
- **book（書籍原稿）** … `preset-ja-technical-writing` + `prh`（ics.media 表記辞書 + 書籍共通追補）。長音、ひらく漢字、重言、呼称のゆれを検出し、さらに書籍規約（章構成、コード提示、図表）でレビューする。箇条書きは「である調」。

機械lintは軽量モデル（Haiku）のサブエージェントに委譲し、文章規範レビュー（段落構成、論証、冗長、LLMっぽい空句など）はメインが担当する。

## 必要なツール

機械lint（markdownlint + textlint）は、固定版のlinterとプリセットを焼き込んだ **Docker イメージ**で実行する。依存は **Docker のみ**。ホストへのlinterグローバル導入は不要で、フォールバックも無い（Dockerが無ければ実行せず、導入方法を案内する）。

- [Docker](https://docs.docker.com/get-docker/)（要インストール）

イメージ（`markdown-review:0.3.0`）はリポジトリ同梱の `docker/Dockerfile` から作る。初回実行時にラッパーが自動でビルドするため通常は手動操作が不要だが、明示的にビルドしたい場合は次のコマンドを実行する。

```sh
docker build -t markdown-review:0.3.0 docker/
```

イメージには以下を固定版で含む（`node:24-alpine` ベース）。`NODE_PATH` によりプリセット解決を保証するため、環境差でtextlintが壊れることはない。

- [`textlint`](https://textlint.org/) と2プリセット（`textlint-rule-preset-ja-technical-writing` / `textlint-rule-preset-jtf-style`）
- [`markdownlint-cli2`](https://github.com/DavidAnson/markdownlint-cli2)

> 実行は cwd をコンテナにマウントする方式のため、**対象ファイルはプロジェクトルート配下の相対パス**で指定する（プロジェクトルートから呼ぶ）。

## インストール

GitHubリポジトリをマーケットプレイスとして追加してインストールする。

```bash
/plugin marketplace add bohnen/markdown-review-skill
/plugin install markdown-review@markdown-review-skill
```

- `markdown-review@markdown-review-skill` は `<plugin 名>@<marketplace 名>`。plugin名は `markdown-review`、marketplace名（リポジトリと同名）は `markdown-review-skill`。
- ローカルで開発・改変する場合は、クローンしたディレクトリを直接指定する（例： `/plugin marketplace add ~/Project/markdown-review`）。

## 使い方

### スラッシュコマンド

```bash
/markdown-review <file> [technical|blog|book]
```

以下は使用例です。

```bash
/markdown-review docs/design.md technical
/markdown-review src/data/blog/2026-07.md blog
/markdown-review Part1/chapter1/chapter1.md book
```

第2引数を省略すると、文書種別をたずねる。

### 自然言語

スキルは次のような依頼で発動する。

- 「この文書を技術文書としてレビューして」
- 「このブログ記事をレビューして」
- 「この章を書籍原稿としてレビューして」
- 「`docs/x.md` にtextlintをかけて整えて」
- 「この文章を推敲して」

種別が読み取れないときはたずねる。

## 動作

1. 対象ファイルを特定する。
2. 文書種別（technical / blog / book）を決める。未指定ならたずねる。
3. Dockerとイメージの有無を確認する（Dockerが無ければ導入を案内し、イメージが無ければ初回に自動ビルドする）。
4. 種別に応じた設定を選ぶ（`config/` を使用）。
5. 機械lintを軽量サブエージェントに委譲（`--fix` → 手修正 → 0件確認）。事実・主張は変更しない。
6. 日本語文書なら文章規範レビューを提案として返す。book では書籍規約のチェックリストも当てる。
7. 種別・使用設定・lint結果・文章規範の指摘をまとめて報告する。

markdownlintは常に実行する。textlint（日本語ルール）と文章規範レビューは日本語文書のみで、非日本語文書ではmarkdownlintだけを実行する。

## 設定ファイル

| ファイル | 用途 |
| --- | --- |
| `config/technical.textlintrc.json` | 技術文書向け（2 プリセット・既定値） |
| `config/blog.textlintrc.json` | ブログ向け（ですます箇条書き） |
| `config/book.textlintrc.json` | 書籍原稿向け（prh 表記辞書付き） |
| `config/prh/` | prh 辞書。ics.media 由来の辞書と書籍共通追補（生成物。正は tidb-break-book の `styleguide/textlint/prh/`） |
| `config/markdownlint.jsonc` | 共通の markdownlint 設定 |
| `skills/markdown-review/references/japanese-tech-writing.md` | 文章規範のリファレンス |
| `skills/markdown-review/references/book-style-guide.md` | 書籍原稿のスタイルガイド本体（汎用版。tidb-break-book の `styleguide/STYLE_GUIDE.md` から書籍固有の項目を除いたもの） |
| `skills/markdown-review/references/book-writing.md` | 書籍原稿の規約の短縮版とレビューチェックリスト（汎用版） |

## ライセンス

Apache-2.0
