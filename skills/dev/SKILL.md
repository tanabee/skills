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

## テスト失敗時の再計画ループ

step 6 (`/test`) でチェックリストの項目に失敗が発生した場合、step 2 (`/plan`) に戻ってやり直す。

- 再計画時は `tmp/issues/<issue番号>/` 配下の既存成果物（`plan.md` / `checklist.md` / `pr.md` など）を新規作成し直すのではなく、失敗内容を反映して**更新**する。各サブスキルは既存ファイルがあれば追記・修正の方針で動作する想定
- `/implement` 以降も、既存の実装・チェックリスト・PR テキストを失敗内容に応じて修正する
- ループ上限は **3 回**（初回実行 + 再計画 2 回 = 最大 3 回の `/test` 実行）。上限に達してもテストが通らない場合はループを終了し、失敗内容をユーザーに報告して判断を仰ぐ
- ループ再突入時の質問頻度は mode に従う。`auto` は確認なしで即ループ、`normal` も原則ループは自動で回すが再計画時の方針選択のみ質問、`careful` は各ループの開始前にユーザーに継続可否を確認

## 注意事項

- mode に応じた質問頻度を守る。`auto` では一切質問しない、`normal` では plan の方針選択のみ、`careful` では各ステップ前に確認する
- `auto` / `normal` の場合、mode で定められていないタイミングでは中断せず最後まで進める
- テスト失敗時は上記「テスト失敗時の再計画ループ」に従う
