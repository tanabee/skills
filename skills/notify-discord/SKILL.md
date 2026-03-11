---
name: notify-discord
description: Discord の Webhook を使ってメッセージを送信する。
allowed-tools: Bash
---

Discord の Webhook でメッセージを送信する。API 仕様は [references/execute-webhook.md](./references/execute-webhook.md) を参照。

1. このファイル（`SKILL.md`）と同じディレクトリにある `config.json` から `webhook_url` を取得する。存在しない場合はユーザーに Webhook URL を質問し、`config.json` に保存する
2. `$ARGUMENTS` をもとに送信内容を決定する。空の場合はユーザーに質問する。`$ARGUMENTS` の内容に応じて JSON リクエストを動的に生成する（シンプルなテキストは `content`、タイトル・説明・色などリッチな表現が必要な場合は `embeds` を使う）。フィールドの詳細は [references/execute-webhook.md](./references/execute-webhook.md) を参照
3. `curl` で `POST <webhook_url>` を実行し、結果をユーザーに報告する
