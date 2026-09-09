---
name: markdown-review
description: Markdown を markdownlint と textlint で機械レビューし、日本語技術文書の文章規範に照らして推敲する。「この文書を技術文書としてレビューして」「このブログをレビューして」「この章を書籍原稿としてレビューして」「markdown をレビュー」「textlint をかけて」「文章を推敲して」などで発動する。技術文書は textlint 標準ルール、ブログは専用ルール（ですます箇条書き）、書籍原稿は prh 表記辞書付きルールと書籍規約を使い分ける。
---

# Markdown レビュー

対象の Markdown を、文書種別に応じたルールで **機械 lint（markdownlint + textlint）** し、さらに **日本語の文章規範** に照らして推敲する。機械チェックは軽量モデルのサブエージェントに委譲し、文章規範レビューはオーケストレータ（メイン）が担う。

文書種別で textlint 設定を切り替える。

- **technical（一般の技術文書）** → textlint 標準ルール（`preset-ja-technical-writing` + `preset-jtf-style` を既定値で）。箇条書きは「である調」。
- **blog（ブログ等）** → `preferInList: "ですます"` を指定した設定。箇条書きも「ですます調」で親しみやすさを優先。
- **book（書籍原稿）** → `preset-ja-technical-writing` + `prh`（ics.media 表記辞書 + 書籍共通追補。長音、ひらく漢字、重言、呼称の統一）。箇条書きは常体・句点なし。さらに `references/book-writing.md` の書籍規約（章構成、コード提示、図表、説明の展開）で構成レビューを行う。

markdownlint は種別に依らず共通設定を使う。

## 手順

### 1. 対象ファイルの特定

コマンド引数、または直近のユーザーメッセージから対象の `.md` を決める。複数指定や glob も可。対象が曖昧なら確認する。

### 2. 文書種別の決定（technical / blog / book）

- ユーザーが「技術文書として」「ブログとして」「書籍原稿として」等と明示していればそれに従う。
- **明示が無ければユーザーにたずねる**（AskUserQuestion。既定動作）。パスや frontmatter から推測できる場合は、推測と根拠を提示したうえで確認する。誤ったルール適用を避けるため、推測だけで確定しない。
  - `pubDatetime` や `tags` を持つ frontmatter（AstroPaper 風）→ blog を提案
  - frontmatter が `author:` だけ、ファイル名が `chapter*.md` / `*preface.md`、見出しに `Chapter N-M` や `第N章` → book を提案

### 3. コンテナの確認（機械 lint は Docker で実行する）

機械 lint は、固定版の linter を焼き込んだ Docker イメージ経由で実行する。ラッパー `${CLAUDE_PLUGIN_ROOT}/bin/mdreview.sh` が docker とパスを隠蔽する。

```bash
command -v docker
```

- **Docker が無ければ実行しない。** ホスト linter へのフォールバックは無い。Docker の導入方法（<https://docs.docker.com/get-docker/>）を案内する。
- イメージ（`markdown-review:0.2.0`）が未ビルドなら、ラッパーが初回に自動で `docker build` する（レジストリ非依存）。プリセット解決はイメージ内の `NODE_PATH` が保証するため、ホスト側のプローブは不要。
- 対象ファイルは **cwd（プロジェクトルート）配下の相対パス**で渡す（ラッパーが cwd を `/work` にマウントする）。

### 4. 設定の選択

設定はリポジトリの `config/` が正で、コンテナへ read-only でマウントされる（ラッパーが `/config` に配置）。種別で textlint 設定を切り替える。

- textlint: `technical`（`config/technical.textlintrc.json`）、`blog`（`config/blog.textlintrc.json`）、`book`（`config/book.textlintrc.json`。prh 辞書は `config/prh/`）
- markdownlint: `config/markdownlint.jsonc`（共通）

ラッパーには種別名（`technical` / `blog` / `book`）だけを渡せばよく、パスは意識しなくてよい。

### 5. 機械レビュー（軽量モデルのサブエージェントに委譲）

`general-purpose` + `model: haiku` のサブエージェントを起動し、次の手順を渡す（`${CLAUDE_PLUGIN_ROOT}` と選択した種別は実際の値に展開して渡すこと）。ラッパーは実行ビットに依存しないよう `sh` 経由で呼ぶ。

1. 現状把握:

   ```bash
   sh "<PLUGIN>/bin/mdreview.sh" markdownlint "<file>"
   sh "<PLUGIN>/bin/mdreview.sh" textlint <type> "<file>"
   ```

2. 自動修正（`--fix` はマウント越しにホストのファイルへ書き戻る）:

   ```bash
   sh "<PLUGIN>/bin/mdreview.sh" markdownlint --fix "<file>"
   sh "<PLUGIN>/bin/mdreview.sh" textlint <type> --fix "<file>"
   ```

3. 残ったエラーを手修正する。事実・主張・固有名・数値は書き換えず、lint 由来の整形と表記だけを直す。

   **どのルールをこの段（機械修正）で直し、どれを step 6（推敲提案）へ回すかを取り違えないこと。** 迷って「未修正」に一括計上すると、機械的に直せるものまで残ってしまう。目安:

   | 区分 | ルール例 | この段での扱い |
   |---|---|---|
   | 機械修正（step 5 で直す） | markdownlint 全般、`prh`（表記ゆれ。book のみ）、`ja-no-mixed-period`（句点欠落）※後述の例外あり、`no-doubled-conjunction`（接続詞重複）、`max-kanji-continuous-len`（漢字連続）、`jtf-style` の記号・表記系、dict 系の冗長表現（`"計算を実行"→"計算する"` 等の言い換え） | その場で直す |
   | 判断を要する（step 5 で直せれば直す／難しければ step 6 で提案） | `no-doubled-joshi`（助詞重複） | 意味を保つ言い換え・語順変更で直す。無理なら提案に回す |
   | 推敲提案（step 6 へ／勝手に確定しない） | `sentence-length`（一文長）、`max-ten`/`max-comma`（読点過多）、`ja-no-weak-phrase`（弱い表現）、`no-mix-dearu-desumasu`（である／ですます混在・`preferInList`） | 件数を記録し、書き換え案は step 6 で提案。文の分割や語調変更は原文の主張・訳文の意図に触れるため自動確定しない |

   - **語を削って解消しない。** 特に `max-kanji-continuous-len`（漢字の連続長）は、語を落として字数を減らすのではなく、助詞・読点で区切って連続を断つ（例: `日本語技術文書の文章規範` → `技術` を削って `日本語の文書作成規範` にするのは NG。`日本語の技術文書の文章規範` のように の で分ける）。`no-doubled-joshi`（助詞重複）も、意味を保つ助詞の言い換え・語順変更で直し、要素を削らない。整形の過程で語義が変わりうる箇所は、その旨を報告に明記する。
   - **`ja-no-mixed-period`（文末が「。」で終わっていない）の例外**: 対象行が「文」でない場合は句点を付けない。具体的には (a) `原文：` `公開日：` `著者：` などのメタ情報行、(b) `〜の課題：` `コスト概算（1時間あたり）:` のように直後の箇条書き・表・コードブロックを導く**コロン止めの導入句**、(c) 図表・画像のキャプションやラベル（`図1: …`、画像 alt 相当の体言止め行、`gateway.yaml — …の設定` など）。いずれも「文」ではないので `。` を足すと誤りになる。誤検知として件数から除外し、報告にその旨を記す。book では加えて、コードブロックのラベル行（```` ```bash コマンド ````）と脚注の URL 行も誤検知として扱う。同様に `max-comma`/`max-ten` が参考文献の著者名列挙行（`Dao, T., Fu, D. Y., …`）に当たる場合も誤検知として扱う。
   - **`prh`（book のみ）**: 製品名の大文字小文字は、プロジェクト側の辞書（プロジェクトの `.textlintrc`）が正。共通辞書の指摘と衝突したら報告に残し、勝手に統一しない。`上で`→`うえで` のように文脈で漢字が正しい場合（位置関係）があるので、`--fix` の結果を必ず読む。
   - **MD034（裸 URL）**: 対象がリンクカード描画（remark のリンクカード変換など、「テキスト == URL のリンクだけの段落」をカード化する仕組み）を使う場合のみ、URL を山括弧 `<https://...>` で囲んで MD034 を満たす。`[表示文字](url)` にはしない。リンクカードを使わない一般文書では、通常の Markdown リンクにしてよい。
4. 再実行し、markdownlint は `Summary: 0 error(s)` を確認する。textlint は step 5 の機械修正対象が 0 になったことを確認し、推敲提案へ回したルール（`sentence-length` 等）と誤検知（メタ行等）の残数を区別して数える。**「未修正◯件」と丸めず、ルール ID ごとに「機械修正済／提案へ／誤検知」を仕分けて報告する。**
5. ルール ID ごとの「件数 / 対応（機械修正済・提案へ・誤検知）」、意味が変わりうる書き換えの有無、最終エラー件数を報告する。

### 6. 文章規範レビュー（日本語文書のみ・メインが担当）

`references/japanese-tech-writing.md`（`${CLAUDE_PLUGIN_ROOT}/skills/markdown-review/references/japanese-tech-writing.md`）を読み込み、規範に照らして推敲観点を提示する。段落構成・論証の厳密さ・演出の抑制・LLM っぽい空句・冗長など、機械 lint では拾えない層を扱う。

- ブログは「ですます」、技術文書は標準（である調の許容）に合わせる。
- **book のときは `references/book-writing.md` も読む。** 前半が書籍原稿の規約の短縮版（文体、章構成、コード提示、図表、表記、説明の展開）、後半がレビュー手順とチェックリスト。チェックリスト（表記・構成・コードと図・内容）を章単位で当て、規約の節番号を添えて指摘する。規約の背景や例が必要なときは `references/book-style-guide.md`（規約の本体）を読む。
- 主観判断を要するため、**提案として返し、事実・主張の書き換えは勝手に確定しない**。重要な書き換えはユーザーに確認する。

### 7. 報告

文書種別、使用した設定、機械 lint の結果（ルール別 件数 / 対応）、文章規範の指摘をまとめて返す。

## 言語の扱い

- markdownlint は常に実行する。
- textlint（日本語ルール）と文章規範レビューは **日本語文書のみ**。非日本語（英語など）の文書では markdownlint だけを実行し、textlint-ja と文章規範はスキップした旨を明記する。

## 参考

- 文章規範の詳細: `references/japanese-tech-writing.md`
- 書籍原稿の規約（短縮版）とチェックリスト: `references/book-writing.md`、規約の本体: `references/book-style-guide.md`
- 設定: `config/technical.textlintrc.json` / `config/blog.textlintrc.json` / `config/book.textlintrc.json` / `config/markdownlint.jsonc`
