---
name: quiz
description: 変更内容の解説(explainer)と理解確認クイズを生成する。マージ前に変更を理解しているか確かめたいとき、「この変更を説明して」「クイズを出して」「変更内容を理解したい」などの依頼で使う。
allowed-tools: Bash, Read, Glob, Grep, Write, AskUserQuestion
---

変更内容を人間が理解しないままマージするのを防ぐため、**変更の解説(explainer)と理解確認クイズ**を 1 つの HTML にまとめて生成する。解説パートは関係者への共有・承認取り付け(pitch)にそのまま使える構成にする。

## 引数

`$ARGUMENTS` は `<対象> [interactive]` の形式。

- `<対象>`: issue 番号 / PR 番号 / URL / 空。空の場合は現在のブランチとベースブランチの差分を対象にする
- `interactive`: 指定された場合、quiz.html 生成後に AskUserQuestion で 1 問ずつ出題する

## 手順

### 1. 対象と保存先の判定

`/review` と同じ規則で判定する: 数値は `gh pr view <番号>` を試し、PR が存在すれば PR モード(保存先 `tmp/prs/<PR番号>/`)、存在しなければ issue として扱いローカルモード(保存先 `tmp/issues/<issue番号>/`)。URL は `/pull/` か `/issues/` で判定。空なら現在のブランチの PR 有無で判定する。

### 2. 材料の収集

- **diff**: PR モードは `gh pr diff`、ローカルモードは `git diff <base>...HEAD`(`<base>` は `tmp/config.json` の `base_branch`。無ければ `git remote show origin` の HEAD branch を検出して保存)
- **成果物**(保存先ディレクトリにあるものだけ使う): `plan.md`(仕様・DoD)/ `report.md`(実装解説)/ `implementation-notes.md`(計画からの逸脱)/ `review.md`(レビュー指摘)— いずれも md が無ければ html を読む / `checklist.html`(テスト結果)/ `screenshots/`(デモ素材)
- diff に現れた変更ファイルは、必要に応じてコードベースの該当箇所を読んで文脈を把握する

### 3. quiz.html の生成

`<保存先>/quiz.html` に **HTML** で書き出す。2 部構成:

**前半: 解説(explainer / pitch)** — 変更を知らない人が読んで内容を理解し、承認判断できる自己完結した構成にする。

- **デモを先頭に**: `screenshots/` があれば主要なスクリーンショットを冒頭に埋め込む(動くものを最初に見せる)
- 何のための変更か(背景・意図)/ 何をしたか(全体像と直感的な説明)/ 仕様(AC)との対応 / 計画からの逸脱(Deviations)とその理由 / レビューでの主要な指摘と対応
- そのまま Slack / Discord 等に共有して buy-in を得られる内容にする

**後半: クイズ** — 「この変更をマージする人が答えられるべきこと」を 5〜10 問。

- 出題観点: 実装方式の選択理由 / エッジケース・エラーパスの扱い / 変更の波及先(副作用)/ 計画からの逸脱箇所 / レビュー指摘のポイント
- 解答と解説は `<details>` で折りたたむ
- 自明な問題で水増ししない。**答えられないとマージ判断に支障がある問い**に絞る

### 4. interactive モード

`interactive` 指定時は、生成したクイズを AskUserQuestion で 1 問ずつ選択式で出題する。回答ごとに正誤と解説を返し、最後に正答数と復習すべき箇所を報告する。

## 注意事項

- 成果物が無く diff しかない場合でも、diff とコードベースの読解から解説とクイズを作る
- `interactive` 指定時を除き、ユーザーへの質問なしで完結する(`/dev` からはサブエージェントとして実行されることがある)
