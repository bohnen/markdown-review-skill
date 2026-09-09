# prh 辞書の構成と出典

書籍原稿向けの prh（表記ゆれ検出）辞書です。`prh.yml` を親として、次のファイルを読み込みます。

| ファイル | 内容 | 出典 |
| --- | --- | --- |
| `dict/prh_idiom.yml` | 誤字・誤用 | ics.media |
| `dict/prh_open_close.yml` | 漢字の閉じ開き | ics.media |
| `dict/prh_redundancy.yml` | 冗長な表現・二重敬語 | ics.media |
| `dict/prh_duplicate.yml` | 重言 | ics.media |
| `dict/prh_cho_on.yml` | 外来語カタカナ表記（-er/-or/-ar は長音付き） | ics.media |
| `dict/prh_corporation.yml` | 社名・ブランド名 | ics.media |
| `dict/prh_web_technology.yml` | ウェブ技術用語 | ics.media |
| `prh-book-common.yml` | 書籍共通の追補。出版社の表記統一指示をルール化したもの | 本プロジェクト |
| `prh-cho-on-extra.yml` | 長音の追補。ics の方針を辞書にない語（サーバー、ユーザーなど）へ拡張 | 本プロジェクト |
| `prh-project-template.yml` | プロジェクト固有の固有名詞ルールの雛形。`prh.yml` からは読み込まない | 本プロジェクト |

`dict/` は [ics-creative/textlint-rule-preset-icsmedia](https://github.com/ics-creative/textlint-rule-preset-icsmedia) の校正辞書（作成者: 池田 泰延）を取り込んだものです。

## dict/ に加えた変更

原則として無改変ですが、次の 1 件だけ削除しています。

- `dict/prh_open_close.yml` の `先程 → さきほど`。出版社の指示（「先ほど」に統一）と矛盾するため。「先ほど」への統一は `prh-book-common.yml` が扱う

## 方針

- ics 辞書と重複する語は追補に入れない。追補は「ics にない語」だけ
- 長音の方針は ics に合わせる。-er/-or/-ar で終わる語は長音付き（サーバー、ユーザー、クラスター、マスター、リーダー）。それ以外は慣用に従う（アーキテクチャ、プライマリ、リカバリ、レイテンシ）。「インターフェイス」も ics に合わせて「フェイス」と書く
- 製品名の大文字小文字（TiDB、MySQL など）はプロジェクトごとに違うため、`prh-project-template.yml` を雛形にプロジェクト側で管理する

## プロジェクトでの使い方

`.textlintrc` の `rulePaths` に親ファイルと、プロジェクト固有ファイルを並べます。

```json
{
  "rules": {
    "prh": {
      "rulePaths": [
        "./styleguide/textlint/prh/prh.yml",
        "./rules/prh-myproject.yml"
      ]
    }
  }
}
```

ルールを追加したら、`specs` に from/to の例を書いておくと、`npx prh` の検証で回帰を防げます。
