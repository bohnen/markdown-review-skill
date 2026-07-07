---
description: Markdown を markdownlint + textlint と日本語文章規範でレビューする
argument-hint: "<file> [technical|blog]"
allowed-tools: ["Bash", "Read", "Edit", "Glob", "Grep", "Task", "AskUserQuestion", "Skill"]
---

ユーザーが `/markdown-review:markdown-review $ARGUMENTS` を実行しました。

`markdown-review` スキルの手順に従って、指定された Markdown をレビューしてください。

- 第 1 引数: 対象ファイル（`.md`）。省略された場合は直近の文脈から対象を判断し、曖昧なら確認する。
- 第 2 引数: 文書種別 `technical` または `blog`。**省略された場合はスキルの手順どおりユーザーにたずねる**（勝手に決めない）。

機械 lint（markdownlint + textlint）は軽量モデルのサブエージェントに委譲し、日本語文書ならさらに文章規範レビューを行い、結果をまとめて報告してください。
