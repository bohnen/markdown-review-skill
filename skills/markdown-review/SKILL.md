---
name: markdown-review
description: Markdown を markdownlint と textlint で機械レビューし、日本語技術文書の文章規範に照らして推敲する。「この文書を技術文書としてレビューして」「このブログをレビューして」「markdown をレビュー」「textlint をかけて」「文章を推敲して」などで発動する。技術文書は textlint 標準ルール、ブログは専用ルール（ですます箇条書き）を使い分ける。
---

# Markdown レビュー

対象の Markdown を、文書種別に応じたルールで **機械 lint（markdownlint + textlint）** し、さらに **日本語の文章規範** に照らして推敲する。機械チェックは軽量モデルのサブエージェントに委譲し、文章規範レビューはオーケストレータ（メイン）が担う。

文書種別で textlint 設定を切り替える。

- **technical（一般の技術文書）** → textlint 標準ルール（`preset-ja-technical-writing` + `preset-jtf-style` を既定値で）。箇条書きは「である調」。
- **blog（ブログ等）** → `preferInList: "ですます"` を指定した設定。箇条書きも「ですます調」で親しみやすさを優先。

markdownlint は種別に依らず共通設定を使う。

## 手順

### 1. 対象ファイルの特定

コマンド引数、または直近のユーザーメッセージから対象の `.md` を決める。複数指定や glob も可。対象が曖昧なら確認する。

### 2. 文書種別の決定（technical / blog）

- ユーザーが「技術文書として」「ブログとして」等と明示していればそれに従う。
- **明示が無ければユーザーにたずねる**（AskUserQuestion。既定動作）。パスや frontmatter（`pubDatetime` や `tags` を持つ AstroPaper 風など）から推測できる場合は、推測と根拠を提示したうえで確認する。誤ったルール適用を避けるため、推測だけで確定しない。

### 3. linter の検出（まず環境にあるものを使う）

```bash
command -v markdownlint-cli2
command -v textlint
```

- どちらか欠けていれば **自動インストールせず、インストール方法をユーザーに問い合わせる**（例: `pnpm add -g` / `npm i -g` / `brew` のどれを使うか）。
- textlint はプリセットが解決できないと動かない。微小サンプルで一度実行し、`No rules found` または `Cannot find module ...preset...` が出たら **プリセット未導入** と判断し、`textlint-rule-preset-ja-technical-writing` と `textlint-rule-preset-jtf-style` のインストール方法をユーザーに問い合わせる。

  ```bash
  printf 'テスト。\n' > /tmp/_mdreview_probe.md
  textlint -c "${CLAUDE_PLUGIN_ROOT}/config/technical.textlintrc.json" /tmp/_mdreview_probe.md; echo "exit=$?"
  ```

  正常に走れば（`No rules found` が出なければ）プリセットは利用可能。

### 4. 設定の選択

- textlint: `${CLAUDE_PLUGIN_ROOT}/config/technical.textlintrc.json` または `${CLAUDE_PLUGIN_ROOT}/config/blog.textlintrc.json`
- markdownlint: `${CLAUDE_PLUGIN_ROOT}/config/markdownlint.jsonc`（共通）

### 5. 機械レビュー（軽量モデルのサブエージェントに委譲）

`general-purpose` + `model: haiku` のサブエージェントを起動し、次の手順を渡す（`${CLAUDE_PLUGIN_ROOT}` と選択した種別は実際の値に展開して渡すこと）。

1. 現状把握:

   ```bash
   markdownlint-cli2 --config "<PLUGIN>/config/markdownlint.jsonc" "<file>"
   textlint -c "<PLUGIN>/config/<type>.textlintrc.json" "<file>"
   ```

2. 自動修正:

   ```bash
   markdownlint-cli2 --fix --config "<PLUGIN>/config/markdownlint.jsonc" "<file>"
   textlint --fix -c "<PLUGIN>/config/<type>.textlintrc.json" "<file>"
   ```

3. 残ったエラーを手修正する。事実・主張・固有名・数値は書き換えず、lint 由来の整形と表記だけを直す。
   - **MD034（裸 URL）**: 対象がリンクカード描画（remark のリンクカード変換など、「テキスト == URL のリンクだけの段落」をカード化する仕組み）を使う場合のみ、URL を山括弧 `<https://...>` で囲んで MD034 を満たす。`[表示文字](url)` にはしない。リンクカードを使わない一般文書では、通常の Markdown リンクにしてよい。
4. 再実行し、markdownlint は `Summary: 0 error(s)`、textlint は終了コード 0 を確認する。
5. ルール ID ごとの「件数 / 対応」、意味が変わりうる書き換えの有無、最終エラー件数を報告する。

### 6. 文章規範レビュー（日本語文書のみ・メインが担当）

`references/japanese-tech-writing.md`（`${CLAUDE_PLUGIN_ROOT}/skills/markdown-review/references/japanese-tech-writing.md`）を読み込み、規範に照らして推敲観点を提示する。段落構成・論証の厳密さ・演出の抑制・LLM っぽい空句・冗長など、機械 lint では拾えない層を扱う。

- ブログは「ですます」、技術文書は標準（である調の許容）に合わせる。
- 主観判断を要するため、**提案として返し、事実・主張の書き換えは勝手に確定しない**。重要な書き換えはユーザーに確認する。

### 7. 報告

文書種別、使用した設定、機械 lint の結果（ルール別 件数 / 対応）、文章規範の指摘をまとめて返す。

## 言語の扱い

- markdownlint は常に実行する。
- textlint（日本語ルール）と文章規範レビューは **日本語文書のみ**。非日本語（英語など）の文書では markdownlint だけを実行し、textlint-ja と文章規範はスキップした旨を明記する。

## 参考

- 文章規範の詳細: `references/japanese-tech-writing.md`
- 設定: `config/technical.textlintrc.json` / `config/blog.textlintrc.json` / `config/markdownlint.jsonc`
