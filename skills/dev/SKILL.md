---
name: dev
description: GitHub issue から計画・実装・チェックリスト・PR テキストまで一気通貫で行う。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Task, Skill, AskUserQuestion
disable-model-invocation: true
---

GitHub issue ( $ARGUMENTS ) に対して、計画から PR テキスト作成まで一気通貫で実行する。

## 引数

`$ARGUMENTS` は `<issue> [mode]` の形式で受け取る。

- `<issue>`: issue 番号（`123`、`#123`）または URL。必須。空の場合はユーザーに issue 番号を質問する。URL が渡された場合は issue 番号を抽出し、以降のステップには正規化済みの issue 番号（例: `123`）を渡す。
- `[mode]`: 慎重度合い。`auto` / `normal` / `careful` のいずれか。省略可。

## モード

| mode | 挙動 |
| --- | --- |
| `auto` | ユーザーに一切質問せず、plan の方針選択も推奨案で自動決定して最後まで進める |
| `normal` | plan の方針選択のみユーザーに質問する。それ以外は中断せず最後まで進める |
| `careful` | 各ステップの開始前と、重要な判断ポイントでユーザーに確認を取る |

`mode` が省略された場合は、最初の手順として AskUserQuestion で mode を選択してもらう（デフォルト推奨は `normal`）。

## 実行手順

以下の順に各スキルを Skill ツールで呼び出す（`<issue番号>` は上記で正規化したもの）。

1. `/research <issue番号>` — issue に関連するコードベースや背景情報を調査する
2. `/plan <issue番号>` — 実装計画を作成し、方針を決定する（`normal` / `careful` ではユーザーに選択してもらう）
3. `/implement <issue番号>` — 計画に基づいてコードを実装する
4. `/create-checklist <issue番号>` — 動作確認チェックリストを作成する
5. `/create-pr-text <issue番号>` — PR のタイトルと説明文を作成する
6. `/test <issue番号>` — チェックリストに沿ってブラウザで動作確認テストを実行する
7. `/review <issue番号>` — コードレビューを行う
8. `/notify-discord` — Discord に実施内容を簡潔にリッチテキスト形式で送信する

## 注意事項

- mode に応じた質問頻度を守る。`auto` では一切質問しない、`normal` では plan の方針選択のみ、`careful` では各ステップ前に確認する
- `auto` / `normal` の場合、mode で定められていないタイミングでは中断せず最後まで進める
