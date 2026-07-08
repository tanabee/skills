---
name: implement
description: GitHub issue と実装計画をもとにコードを実装する。計画からの逸脱は implementation-notes.md に記録しながら進める。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Skill, TaskCreate, TaskUpdate, TaskList
---

GitHub issue ( $ARGUMENTS ) の内容をもとに実装を行う。

## 引数

`$ARGUMENTS` は `<issue> [mode]` の形式で受け取る。

- `<issue>`: issue 番号(`123`、`#123`)または URL。空の場合はユーザーに issue 番号を質問する
- `[mode]`: `auto` / `normal`。`auto` の場合、実装中に要件が不明確でもユーザーに質問せず、**保守的な選択肢を選んで implementation-notes.md に記録して続行する**。省略時は質問してよい

## implementation-notes.md(実装ノート)

実装開始時に `tmp/issues/<issue番号>/implementation-notes.md` を作成する(既にあれば追記)。**計画と実装現場のギャップをリアルタイムに記録する**ためのファイルで、後工程(`/test` のチェックリスト整合、`/review` / `/quiz` のコンテキスト、`/dev` の config 学習)の一次情報になる。

- **計画から逸脱せざるを得ない事象**(plan に無いエッジケース、想定と異なる既存実装、依存の発見など)に遭遇したら、**その時点で**保守的な選択肢を選び、`## Deviations` セクションに「何が起きたか / なぜ逸脱したか / どう対処したか」を記録して続行する
- 発見したエッジケース・後続ステップへの注意点は `## Notes` セクションに記録する
- 事後にまとめて書くのではなく、**発生の都度追記する**(コンテキスト圧縮や中断を跨いでも判断の履歴が残るように)

## タスク管理

実装の進行状況は Claude Code のタスク管理ツール(TaskCreate / TaskUpdate / TaskList)で管理する。

### 初期化

`plan.html` を読み込んだ直後に、計画書に記載された各タスク(および TDD の Red / Green / Refactor フェーズ)を `TaskCreate` で一括登録する。命名規則の例:

- `task-1-red` / `task-1-green` / `task-1-refactor`
- `task-2-red` / `task-2-green` / `task-2-refactor`
- ...
- `final-test-run`(全タスク完了後の既存テスト実行)
- `report`(report.html 書き出し)

### 進行管理ルール

- 各フェーズに入る直前に該当タスクを `in_progress` に変更
- フェーズが正常完了したら即座に `completed` に変更(**バッチ更新しない**)
- 同時に `in_progress` にできるのは **1 タスクのみ**
- タスクの完了条件を満たせず実装を中断する場合は、理由を implementation-notes.md に記録した上でユーザーに報告する

## 実行手順

1. `tmp/issues/<issue番号>/plan.html` を確認する。なければユーザーに `plan` スキルの実行を提案する
2. `gh issue view` で issue を取得し、目的・要件を把握する
3. implementation-notes.md を作成する(上記参照)
4. plan.html のタスク・フェーズ構成を読み込み、`TaskCreate` で実装タスクを一括登録する
5. `plan.html` のタスクを上から順に実装する。各タスクの影響範囲に記載されたファイルを確認してから変更する。計画とのズレが出たら implementation-notes.md に記録する
6. 各タスクの完了条件を満たしていることを確認し、`/simplify` スキルでコードを整理した後、次のタスクに進む
7. 全タスク完了後、既存のテストがあれば実行して通ることを確認する
8. 実装の解説を `tmp/issues/<issue番号>/report.html` に **HTML** として書き込む(implementation-notes.md を材料にする)

HTML を採用する理由: タスクごとのカード化・テスト結果の色分け・Mermaid でのアーキテクチャ図など、Markdown では困難なリッチ表現を使うため。

### 出力構造(必須セクション)

レイアウトや図表は実装内容に応じて自由に設計してよい(テンプレートは置かない)。ただし `/review` / `/quiz` / `/create-pr-text` がレポートを参照しやすいよう、以下のセクションは見出し(`<h2>` 等)として含めること。

- **概要**: 何を実装したかのサマリ
- **タスクごとの実装内容**: 各タスクの変更ファイル・主要な変更点・完了条件の達成状況
- **計画からの逸脱**: implementation-notes.md の Deviations の要約(逸脱なしならその旨)
- **テスト結果**: 既存テストの実行結果(成功/失敗)
- **懸念点・追加変更**: 計画外の変更や、レビュアに注意してほしい点

## 注意事項

- 実装中に要件が不明確な場合はユーザーに確認を取る(`auto` では保守的に選択し、Deviations に記録して続行する)
- タスクの完了条件を満たせない場合は、その理由をユーザーに伝える
- コミットは行わない(ユーザーが任意のタイミングで実施する)
