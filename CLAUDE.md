# Project: markdown-review（Claude Code プラグイン）

## 概要

Markdown を **markdownlint + textlint** で機械レビューし、さらに **日本語技術文書の文章規範** に照らして推敲する、インストール可能な Claude Code プラグイン。文書種別（technical / blog）で textlint のルールを使い分ける。

もとは個人ブログ `readuncommitted` で育てた 2 スキル（`blog-lint-review` の機械 lint と `japanese-tech-writing` の文章規範）を、リポジトリ外でも使えるプラグインに統合したもの。`config/blog.textlintrc.json` はそのブログの `.textlintrc.json` と同内容。

## ディレクトリ構成

```
markdown-review/
├── .claude-plugin/
│   ├── plugin.json         # マニフェスト（name: markdown-review）
│   └── marketplace.json    # ローカルインストール用（source: "./"）
├── commands/
│   └── markdown-review.md   # /markdown-review <file> [technical|blog]
├── skills/markdown-review/
│   ├── SKILL.md             # オーケストレータ本体（発動条件と手順）
│   └── references/
│       └── japanese-tech-writing.md   # 文章規範のリファレンス
└── config/
    ├── technical.textlintrc.json   # 技術文書＝2プリセット・既定値
    ├── blog.textlintrc.json        # ブログ＝ですます箇条書き
    └── markdownlint.jsonc          # 共通の markdownlint 設定
```

- スキル/コマンドは **ディレクトリ規約で自動検出** される。`plugin.json` に列挙は不要。
- バンドルファイルは SKILL.md / コマンドから **`${CLAUDE_PLUGIN_ROOT}/...`** で参照する（相対・絶対パスを使わない）。

## 設計上の決めごと（変更時に守る）

- **文書種別で textlint 設定を切り替える。** technical = `preset-ja-technical-writing` + `preset-jtf-style`（既定値、箇条書きは「である」）。blog = `no-mix-dearu-desumasu` の `preferInList: "ですます"`（本文も箇条書きも「ですます」）。**種別が未指定なら勝手に決めずユーザーにたずねる。**
- **環境の linter をまず使う。** 無い場合やプリセットが解決できない（`No rules found` / `Cannot find module ...preset...`）場合は **自動インストールせず、インストール方法をユーザーに問い合わせる。**
- **markdownlint は常時、textlint（日本語ルール）と文章規範レビューは日本語文書のみ。** 非日本語は markdownlint だけを実行し、スキップした旨を明記する。
- **機械 lint は軽量モデル（`general-purpose` + `model: haiku`）のサブエージェントに委譲**、文章規範レビュー（判断を要する層）はメインが `references/japanese-tech-writing.md` を参照して担当する。
- **事実・主張・固有名・数値は書き換えない。** lint 由来の整形と表記だけを直し、内容の推敲は提案として返す。
- **MD034（裸 URL）** は、対象がリンクカード描画（remark のリンクカード変換など）を使う場合のみ `<https://...>` の山括弧化で対応する。一般文書では通常のリンクでよい。

## 動作環境（確認済み）

- Node v18.12.1 で動作。`textlint` v15.7.1、`markdownlint-cli2` v0.23.0（いずれも pnpm global）。
- textlint プリセット `textlint-rule-preset-ja-technical-writing@12.0.2` / `textlint-rule-preset-jtf-style@3.0.3` がグローバルに解決できること。
- 導入例: `pnpm add -g textlint textlint-rule-preset-ja-technical-writing textlint-rule-preset-jtf-style markdownlint-cli2`

## 開発・テスト

### ローカルインストールと反映

```
/plugin marketplace add ~/Project/markdown-review
/plugin install markdown-review@markdown-review
# 変更後は
/reload-plugins
```

### 手動での挙動確認（`${CLAUDE_PLUGIN_ROOT}` はこのリポジトリのパスに読み替える）

```sh
# markdownlint（JSONC 設定・--fix）
markdownlint-cli2 --config config/markdownlint.jsonc <file.md>
markdownlint-cli2 --fix --config config/markdownlint.jsonc <file.md>

# textlint（種別ごとの設定）
textlint -c config/technical.textlintrc.json <file.md>
textlint -c config/blog.textlintrc.json <file.md>
```

### 設定切り替えの回帰確認

箇条書きが「ですます」で終わる文書を用意し、`blog` 設定では `no-mix-dearu-desumasu` が出ず、`technical` 設定では「"である"調 でなければなりません」が出ることを確認する（両設定の差分の要）。

## 注意事項

- JSON 設定（`technical.textlintrc.json` / `blog.textlintrc.json` / `plugin.json` / `marketplace.json`）は厳密な JSON。`markdownlint.jsonc` はコメント可（markdownlint-cli2 が解釈）。
- 対象プロジェクトに `.markdownlint-cli2.jsonc` があると ignore glob 等が混入しうる。設定は必ず `--config` で明示する。
- 文章規範を更新するときは `skills/markdown-review/references/japanese-tech-writing.md` を編集する（SKILL.md 本体ではない）。
- リリース時は `plugin.json` の `version` を更新する。
