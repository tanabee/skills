---
name: create-pr-text
description: GitHub issue から PR のタイトルと説明文を作成する。
allowed-tools: Bash, Read, Glob, Grep, Write
---

GitHub issue から PR のタイトルと説明文を作成する。`$ARGUMENTS` に issue 番号(`123`、`#123`)または URL が渡される。`$ARGUMENTS` が空の場合はユーザーに issue 番号を質問する。

**実際の PR は絶対に作成しない。** `gh pr create` は実行禁止。テキストの生成のみ行う。

本スキルはユーザーへの質問なしで完結する(`/dev` からはサブエージェントとして実行されることがある)。

1. `tmp/config.json` を確認する:
   - `pull_request_template_path`: なければプロジェクト内の PR テンプレート(`pull_request_template.md`, `.github/pull_request_template.md` 等)を探し、見つかったパスを保存する。テンプレートがあればそのフォーマットに従う
   - `base_branch`: なければ `git remote show origin` の HEAD branch を検出して保存する(以降 `<base>`)
2. `tmp/issues/<issue番号>/` 配下に `plan.md` / `report.md`(md が無ければ html)/ `checklist.html` / `implementation-notes.md` が既にある場合はその内容を活用する(特に implementation-notes の Deviations は「計画との差分」としてレビュアに有用)
3. `gh issue view` で issue を取得する
4. `git log <base>..HEAD --stat` でコミット単位の変更概要を確認し、必要に応じて `git show <hash>` で個別のコミット内容を把握する
5. 結果を Write ツールで `tmp/issues/<issue番号>/pr.md` に書き込む(フォーマットは [template.md](./assets/template.md) を参照)

## 書き方の方針

詳細は diff や issue を見れば分かるので、PR テキストは最小限に留める。冗長な説明や同じ内容の言い換えは書かない。

- **概要**: 1-3 行。何のための変更かが分かる程度
- **変更内容**: 各項目は短く(1 行が長くなりそうなら粒度を見直す)。網羅的に列挙せず、主要な変更のみ
- **関連 Issue**: `closes #<番号>` のみ

PR テンプレートがある場合はそのセクション構成に従いつつ、各セクションは上記の粒度で簡潔に書く。
