# CLAUDE.md

このリポジトリで作業する際の設計上の決めごとと開発・テスト手順。

## 何をするプラグインか

Markdown を文書種別（technical / blog / book）に応じて **機械 lint（markdownlint + textlint）** し、さらに **日本語の文章規範** に照らして推敲する Claude Code プラグイン。機械 lint は Haiku サブエージェントへ委譲し、文章規範レビューはメインが担当する。

## 設計上の決めごと

- **機械 lint は固定版 Docker イメージで実行する。依存は Docker のみ。**
  - 以前はホストにグローバル導入した textlint / markdownlint-cli2 を使っていたが、textlint のプリセット解決が Node 版・pnpm/npm の global レイアウトに敏感で壊れやすかった。これを、linter とプリセットを固定版で焼き込んだイメージ（`markdown-review:0.3.0`）に一本化した。
  - **ホスト linter へのフォールバックは廃止。** Docker が無ければ実行せず、導入方法を案内する。
  - SKILL は直接 linter を叩かず、唯一の入口 `bin/mdreview.sh`（薄いラッパー）経由で `docker run` する。ラッパーは実行ビットに依存しないよう `sh` 経由で呼ぶ。
- **設定はリポジトリの `config/` が正。** コンテナへ read-only（`/config`）でマウントする。バージョン管理・編集性を維持するため、イメージには焼き込まない。book 用の prh 辞書（`config/prh/`）も同じマウントで `/config/prh/prh.yml` として解決する。
- **book 種別の prh 辞書は生成物。** 正は `tidb-break-book` リポジトリの `styleguide/textlint/prh/`。編集はそちらで行い、`styleguide/scripts/sync-to-plugin.sh` で `config/prh/` を上書きする。ここで直接編集しない。
- **book 種別の規約（`references/book-style-guide.md` / `book-writing.md`）はこのリポジトリが正。** 元は同リポジトリの `styleguide/STYLE_GUIDE.md` などだが、書籍固有の項目（タグ名、コラムの閉じマーカー、ファイル構成、出版社指示）を除いた汎用版として別管理する。2 ファイルの内容が食い違わないよう、片方を直したらもう片方も直す。
- **book 種別は共通辞書だけを持つ。** 製品名の大文字小文字などプロジェクト固有の prh ルールは、対象プロジェクトの `.textlintrc` で管理する（プラグインには入れない）。
- **プリセット解決はイメージ内の `NODE_PATH` で保証する。** config を `/config` にマウントしても textlint がルールを解決できる。これが本方式の要。
- **配布はレジストリ非依存。** リポジトリ同梱の `docker/Dockerfile` を初回に `docker build`（ラッパーが自動実行）。GHCR への publish / CI はスコープ外。
- **--fix はマウント越しにホストへ書き戻る。** `docker run -u $(id -u):$(id -g)` で実行し、書き戻したファイルが root 所有にならないようにする。

## 動作環境（確認済み）

- ベースイメージ: `node:24-alpine`（現行 Active LTS）。
  - 固定版の要求 Node は textlint@15.7.1 が `>=20`、markdownlint-cli2@0.23.0 が `>=22`。node:18 では動かない。
- 焼き込む固定版（`docker/package.json`）:
  - `markdownlint-cli2` 0.23.0
  - `textlint` 15.7.1
  - `textlint-rule-preset-ja-technical-writing` 12.0.2
  - `textlint-rule-preset-jtf-style` 3.0.3
  - `textlint-rule-prh` 6.1.0
  - `textlint-filter-rule-comments` 1.3.0
  - `textlint-filter-rule-allowlist` 4.0.0
- イメージはサイズ最小化のため、単一 RUN 内で `npm install` → `cache clean` → 不要物（`*.md` / `*.ts`(型定義) / `*.map` / `test`・`docs` ディレクトリ）の prune まで完結させる。`LICENSE` は残す。
  - lockfile は同梱しない（直接依存は exact pin 済み）。完全確定性が要れば `docker/package-lock.json` + `npm ci` に切替可能。

## ファイル構成

| パス | 役割 |
|---|---|
| `skills/markdown-review/SKILL.md` | スキル本体の手順 |
| `skills/markdown-review/references/japanese-tech-writing.md` | 文章規範リファレンス |
| `skills/markdown-review/references/book-style-guide.md` | 書籍原稿のスタイルガイド本体（汎用版・このリポジトリが正） |
| `skills/markdown-review/references/book-writing.md` | 書籍原稿の規約の短縮版とレビューチェックリスト（汎用版・同上） |
| `commands/markdown-review.md` | スラッシュコマンド定義 |
| `bin/mdreview.sh` | docker 実行を隠蔽するラッパー（SKILL が呼ぶ唯一の入口） |
| `docker/Dockerfile` / `docker/package.json` | 実行ランタイムのイメージ定義 |
| `config/*.textlintrc.json` / `config/markdownlint.jsonc` | lint 設定（リポジトリが正・マウントで注入） |
| `config/prh/` | book 用 prh 辞書（生成物・マウントで注入） |

## 開発・テスト

### イメージのビルドと健全性確認

```sh
docker build -t markdown-review:0.3.0 docker/
docker run --rm markdown-review:0.3.0 markdownlint-cli2 --version
docker run --rm markdown-review:0.3.0 textlint --version
docker images markdown-review:0.3.0   # サイズ確認
```

### ラッパー経由の手動確認

プロジェクトルートから、cwd 配下の相対パスで呼ぶ。

```sh
sh bin/mdreview.sh markdownlint sample.md
sh bin/mdreview.sh textlint technical sample.md
sh bin/mdreview.sh markdownlint --fix sample.md    # ホスト側 sample.md が整形される
```

### 回帰確認（種別差分）

箇条書きが「ですます」で終わる md に対し、`blog` は `no-mix-dearu-desumasu` を出さず、`technical` は「"である"調」を要求する（`config/blog.textlintrc.json` の `preferInList` が効いていること）。

```sh
sh bin/mdreview.sh textlint blog sample.md       # no-mix-dearu-desumasu は出ない
sh bin/mdreview.sh textlint technical sample.md  # "である"調 の指摘が出る
sh bin/mdreview.sh textlint book sample.md       # 加えて prh（サーバ→サーバー など）が出る
```

### プラグイン経由

`/reload-plugins` 後、`/markdown-review sample.md technical` が一連（種別判定 → コンテナ lint → 文章規範）で通ることを確認する。
