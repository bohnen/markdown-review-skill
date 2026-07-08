# markdown-review

Markdown を **markdownlint + textlint** で機械レビューし、さらに **日本語技術文書の文章規範** に照らして推敲する Claude Code プラグイン。文書種別で textlint のルールを使い分ける。

- **technical（一般の技術文書）** … textlint 標準ルール（`preset-ja-technical-writing` + `preset-jtf-style` を既定値で）。箇条書きは「である調」。
- **blog（ブログ等）** … `no-mix-dearu-desumasu` を `preferInList: "ですます"` に設定。本文も箇条書きも「ですます調」で統一し、親しみやすさを優先。

機械 lint は軽量モデル（Haiku）のサブエージェントに委譲し、文章規範レビュー（段落構成・論証・冗長・LLM っぽい空句など）はメインが担当する。

## 必要なツール

機械 lint（markdownlint + textlint）は、固定版の linter とプリセットを焼き込んだ **Docker イメージ**で実行する。依存は **Docker のみ**。ホストへの linter グローバル導入は不要で、フォールバックも無い（Docker が無ければ実行せず、導入方法を案内する）。

- [Docker](https://docs.docker.com/get-docker/)（要インストール）

イメージ（`markdown-review:0.2.0`）はリポジトリ同梱の `docker/Dockerfile` から作る。初回実行時にラッパーが自動でビルドするため通常は手動操作は不要だが、明示的にビルドしたい場合:

```sh
docker build -t markdown-review:0.2.0 docker/
```

イメージには以下が固定版で含まれる（`node:24-alpine` ベース）。`NODE_PATH` によりプリセット解決を保証するため、環境差で textlint が壊れることがない。

- [`textlint`](https://textlint.org/) と 2 プリセット（`textlint-rule-preset-ja-technical-writing` / `textlint-rule-preset-jtf-style`）
- [`markdownlint-cli2`](https://github.com/DavidAnson/markdownlint-cli2)

> 実行は cwd をコンテナにマウントする方式のため、**対象ファイルはプロジェクトルート配下の相対パス**で指定する（プロジェクトルートから呼ぶ）。

## インストール（ローカル）

```
/plugin marketplace add ~/Project/markdown-review
/plugin install markdown-review@markdown-review
```

## 使い方

### スラッシュコマンド

```
/markdown-review <file> [technical|blog]
```

例:

```
/markdown-review docs/design.md technical
/markdown-review src/data/blog/2026-07.md blog
```

第 2 引数を省略すると、文書種別をたずねる。

### 自然言語

スキルは次のような依頼で発動する。

- 「この文書を技術文書としてレビューして」
- 「このブログ記事をレビューして」
- 「`docs/x.md` に textlint をかけて整えて」
- 「この文章を推敲して」

種別が読み取れないときはたずねる。

## 動作

1. 対象ファイルを特定する。
2. 文書種別（technical / blog）を決める。未指定ならたずねる。
3. Docker とイメージの有無を確認する（Docker が無ければ導入を案内し、イメージが無ければ初回に自動ビルドする）。
4. 種別に応じた設定を選ぶ（`config/` を使用）。
5. 機械 lint を軽量サブエージェントに委譲（`--fix` → 手修正 → 0 件確認）。事実・主張は変更しない。
6. 日本語文書なら文章規範レビューを提案として返す。
7. 種別・使用設定・lint 結果・文章規範の指摘をまとめて報告する。

markdownlint は常に実行する。textlint（日本語ルール）と文章規範レビューは日本語文書のみで、非日本語文書では markdownlint だけを実行する。

## 設定ファイル

| ファイル | 用途 |
|---|---|
| `config/technical.textlintrc.json` | 技術文書向け（2 プリセット・既定値） |
| `config/blog.textlintrc.json` | ブログ向け（ですます箇条書き） |
| `config/markdownlint.jsonc` | 共通の markdownlint 設定 |
| `skills/markdown-review/references/japanese-tech-writing.md` | 文章規範のリファレンス |

## ライセンス

Apache-2.0
