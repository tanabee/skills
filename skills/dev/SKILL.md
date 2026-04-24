---
name: dev
description: GitHub issue から計画・実装・チェックリスト・PR テキストまで一気通貫で行う。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Task, Skill
disable-model-invocation: true
---

GitHub issue ( $ARGUMENTS ) に対して、計画から PR テキスト作成まで一気通貫で実行する。`$ARGUMENTS` は issue 番号（`123`、`#123`）または URL。`$ARGUMENTS` が空の場合はユーザーに issue 番号を質問する。URL が渡された場合は issue 番号を抽出し、以降のステップには正規化済みの issue 番号（例: `123`）を渡す。

以下の順に各スキルを Skill ツールで呼び出す（`<issue番号>` は上記で正規化したもの）。

1. `/research <issue番号>` — issue に関連するコードベースや背景情報を調査する
2. `/plan <issue番号>` — 実装計画を作成し、ユーザーに方針を選択してもらう
3. `/implement <issue番号>` — 計画に基づいてコードを実装する
4. `/create-checklist <issue番号>` — 動作確認チェックリストを作成する
5. `/create-pr-text <issue番号>` — PR のタイトルと説明文を作成する
6. `/review` — コードレビューを行う
7. `/notify-discord` — Discord に実施内容を簡潔にリッチテキスト形式で送信する

## 注意事項

- ユーザーに確認を取らず、全ステップを連続で実行する。途中で止まらないこと
- plan の方針選択のみユーザーに質問する。それ以外は中断せず最後まで進める
