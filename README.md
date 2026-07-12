# Skills

GitHub Issue 駆動開発を中心とした Claude Code スキル集です。

## スキル一覧

### Issue 駆動開発ワークフロー

| スキル | コマンド | 説明 |
|-------|---------|------|
| dev | `/dev <issue> [auto\|normal]` | research → plan → review-plan → implement → create-pr-text → test → review → quiz → notify-discord を一気通貫で実行 |
| research | `/research <issue>` | 受け入れ条件・影響範囲・実装方法の候補を整理する（選択は plan に委ねる） |
| plan | `/plan <issue>` | research の結果をもとに実装方法を選択し、TDD ベースの実装計画と動作確認チェックリストを作成 |
| review-plan | `/review-plan <issue>` | plan の影響範囲を独立視点で検証し、修正必須/任意改善として差し戻す |
| implement | `/implement <issue>` | plan に基づいてコードを実装 |
| create-pr-text | `/create-pr-text <issue>` | Issue と計画から PR タイトル・説明文を作成（PR 自体は作成しない） |
| test | `/test <issue>` | chrome-devtools でチェックリストに沿ってブラウザ動作確認を実行 |
| review | `/review <issue>` | Claude Code と Codex CLI を並列実行してコードレビュー（全観点を網羅）し、結果を統合 |
| codex-review | `/codex-review` | Codex CLI にコードレビューを依頼（`/review` から内部呼び出しされる。単独実行も可） |
| quiz | `/quiz [<issue\|PR>] [interactive]` | 変更内容の解説（explainer）と理解確認クイズを生成。空指定なら現在のブランチ差分が対象 |

### ツール系

| スキル | コマンド | 説明 |
|-------|---------|------|
| browser | `/browser` | chrome-devtools-mcp の CLI を使ったブラウザ操作（既存接続 or テスト起動を毎回確認） |
| cloud-logging | `/cloud-logging <自然言語クエリ>` | gcloud CLI 経由で Cloud Logging のログを取得・分析 |
| notify-discord | `/notify-discord <メッセージ>` | Discord Webhook でメッセージを送信（初回は webhook URL を保存） |
| nanobanana | `/nanobanana <プロンプト> [--model flash\|pro] [--aspect 16:9] [--size 1K]` | Gemini の画像生成モデル (nanobanana) で画像生成し `tmp/images/` に保存。`GEMINI_API_KEY` 必須 |
| prototype | `/prototype [アイデア]` | アイデアの壁打ち（発散→収束）から、スタック選定・実装・動作確認・デモ整備・フィードバックループまで一気通貫でプロトタイプを作る |
| open | `/open <path>` | ファイルやフォルダを種別に応じて開き分ける（`.md` は grip でブラウザ表示、`.html` はデフォルトブラウザ、フォルダは Finder、その他は Antigravity IDE） |
| copy | `/copy <path\|text>` | ファイルの中身・テキスト・会話中の直前の出力をクリップボードにコピー（画像は osascript で画像としてコピー） |

### Firebase 統合

| スキル | 説明 |
|-------|------|
| firebase-auth-internal-app | Firebase Auth を社内向けアプリに統合（Blocking Functions によるドメイン制限、Firestore へのユーザー登録を含む） |

## 出力

各 Issue 駆動スキルの成果物は `tmp/issues/<issue番号>/` 配下に出力されます。

- `research.md` / `.html` - 調査結果
- `plan.md` / `.html` - 実装計画
- `review-plan.md` / `.html` - 計画レビュー結果
- `checklist.html` - 動作確認チェックリスト（`/test` が結果を書き込む状態ファイルのため html 単一）
- `implementation-notes.md` - 計画からの逸脱メモ
- `report.md` / `.html` - 実装レポート
- `pr.md` - PR タイトル・説明文（PR 本文用のため md のまま）
- `review.md` / `.html` - コードレビュー結果
- `quiz.html` - 変更内容の解説と理解確認クイズ
- `screenshots/` - `/test` のスクリーンショット

主要な成果物は **md（正・スキル間の伝達用）と HTML（人間レビュー用ビュー）の 2 種**で生成されます。HTML は AC カバレッジ表・TDD フェーズの色分け・Mermaid によるフローチャートやアーキテクチャ図など、Markdown では実現困難なリッチ表現で構造を立体的に伝えるためのものです。

## `/dev` の挙動

`/dev` は mode で質問頻度を制御します。

| mode | 挙動 |
| --- | --- |
| `auto` | 一切質問せず推奨案で最後まで進める |
| `normal` | plan の方針選択と config 追記の承認のみ質問 |

- **開始時に「どのステップ完了後に停止してユーザーがレビューするか」を選択できます**（mode に関わらず適用。`implement` 完了後だけ止めて確認、などが可能）
- **開始時に「スキップするステップ」も選択できます**（例: PR を作らない場合は `create-pr-text` をスキップ、ローカル確認のみなら `notify-discord` をスキップ）
- **作業開始前に `issue-<issue番号>` ブランチに切り替えます**（無ければベースブランチから自動作成。未コミットの変更がある場合は中断してユーザーに対処を促します）
- `/review-plan` で**修正必須**が出た場合は `/plan` → `/review-plan` のサブループを最大 3 回まで回します
- `/test` でチェックリスト失敗時は `/plan` から再計画するループを最大 3 回まで回します
- `/review` で **must 指摘**が出た場合は `/implement`（修正）→ `/review` のループを最大 3 回まで回します
- 再計画で見落としが判明した間接依存・暗黙の必須セットは、`plan` / `review-plan` の `config.json` の `attentions` に追記され、以降の手戻り防御に転用されます

## インストール

```bash
# 全スキル
npx skills add tanabee/skills --skill '*'

# 対話的に選択
npx skills add tanabee/skills
```
